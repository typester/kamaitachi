package Kamaitachi::IO;
use Any::Moose;

extends 'Data::AMF::IO';

use Scalar::Util;
use AnyEvent::Handle;
use Carp;
use Data::AMF::Formatter::AMF0;
use Data::AMF::Parser::AMF0;

use Kamaitachi::Packet;

has fh => (
    is       => 'rw',
    required => 1,
);

has handle => (
    is         => 'rw',
    lazy_build => 1,
    handles    => ['on_error', 'on_eof'],
);

has buffer => (
    is      => 'rw',
    default => '',
);

has buffer_length => (
    is         => 'rw',
    lazy_build => 1,
);

has cursor => (
    is      => 'rw',
    default => 0,
);

has [qw/read_chunk_size write_chunk_size/] => (
    is      => 'rw',
    default => 128,
);

has read_packet_cache => (
    is      => 'rw',
    default => sub { [] },
);

has write_packet_cache => (
    is      => 'rw',
    default => sub { [] },
);

has amf0_formatter => (
    is         => 'rw',
    lazy_build => 1,
    handles    => { encode_amf => 'format' },
);

has amf0_parser => (
    is         => 'rw',
    lazy_build => 1,
    handles    => { decode_amf => 'parse' },
);

no Any::Moose;

sub handle_client_handshaking {
    my ($self, %callbacks) = @_;

    $callbacks{on_complete}
        or Carp::croak 'on_complete callback is required';
    $self->{_callbacks} = \%callbacks;

    my $h = $self->handle;
    $h->push_read(chunk => 1, sub {
        my $handle = $_[0];
        my $data   = unpack 'C', $_[1];

        if ($data == 3) {
            $handle->push_write($_[1]);
        }
        else {
            my $cb = $self->{_callbacks}{on_fail};
            if ($cb) {
                $cb->($handle, 'invalid version');
            }
            else {
                $handle->push_shutdown;
            }
        }
    });

    my $client_packet;
    $h->push_read(chunk => 0x600, sub {
        my ($handle, $chunk) = @_;
        $client_packet = $chunk;

        my $server_packet = pack('N', time)
            . pack('C*', 0, 0, 0, 0);
        $server_packet .= pack('C', int rand 0xff) for 1 .. (0x600-8);
        $handle->push_write($server_packet);
        $handle->push_write($client_packet);

        $handle->push_read(chunk => 0x600, sub {
            my ($handle, $chunk) = @_;

            if ($chunk eq $server_packet) {
                $self->{_callbacks}{on_complete}->($handle);
            } else {
                $self->{_callbacks}{on_complete}->($handle);
                return;

                # Weird: sometimes happen this even if client is official flash player.
                my $cb = $self->{_callbacks}{on_fail};
                if ($cb) {
                    $cb->($handle, 'invalid client echo');
                }
                else {
                    $handle->push_shutdown;
                }
            }
        });
    });
    Scalar::Util::weaken($self);
}

sub handle_rtmp_packet {
    my ($self, %callbacks) = @_;

    $callbacks{on_packet}
        or Carp::croak 'on_packet callback is required';
    $self->{_callbacks} = \%callbacks;

    $self->handle->on_read(sub {
        my ($handle) = @_;

        $self->push(delete $handle->{rbuf});

        while (my $packet = $self->get_rtmp_packet) {
            if ($packet->is_full) {
                # handle chunk size automatically
                if ($packet->type == 0x01) {
                    my $size = unpack 'N', $packet->data;
                    $self->read_chunk_size($size);
                }
            }

            $self->{_callbacks}{on_packet}->($packet) if $self;
        }
    });
    Scalar::Util::weaken($self);
}

sub reset_fh {
    my ($self, $fh) = @_;

    $self->fh($fh);
    $self->clear_handle;
}

sub push {
    my ($self, $bytes) = @_;
    $self->clear_buffer_length;
    $self->{buffer} .= $bytes;
}

sub reset {
    my ($self, $bytes) = @_;
    $self->clear_buffer_length;
    $self->cursor(0);

    return;
}

sub spin {
    my ($self) = @_;

    my $read        = substr $self->buffer, 0, $self->cursor;
    $self->{buffer} = substr $self->buffer, $self->cursor;
    $self->reset;

    $read;
}

sub read {
    my ($self, $len) = @_;

    return if $self->buffer_length < ($self->cursor + $len);

    my $data = substr $self->buffer, $self->cursor, $len;
    $self->{cursor} += $len;

    $data;
}

sub write {
    my ($self, $packet_or_data) = @_;

    if (ref $packet_or_data) {
        if ($packet_or_data->isa('Kamaitachi::Packet::Function')) {
            my $data = $self->amf0_formatter->format(
                $packet_or_data->method,
                $packet_or_data->id,
                @{ $packet_or_data->args },
            );

            $packet_or_data->data($data);
            $packet_or_data->size(length $data);
            $packet_or_data->filled( $packet_or_data->size );

            $self->handle->push_write( $self->serialize_packet($packet_or_data) );
        }
        elsif ($packet_or_data->isa('Kamaitachi::Packet')) {
            $self->handle->push_write( $self->serialize_packet($packet_or_data) );
        }
        else {
            Carp::croak 'unknown packet object: ', ref $packet_or_data;
        }
    }
    else {
        $self->handle->push_write($packet_or_data);
    }
}

sub serialize_packet {
    my ($self, $packet, $chunk_size) = @_;
    $chunk_size ||= $self->write_chunk_size;

    my $io = Data::AMF::IO->new( data => q[] );

    my $first = 0;
    my $cached = $self->write_packet_cache->[ $packet->number ];
    if ($cached) {
        if ($cached->stream_id != $packet->stream_id) {
            # require full packet
        }
        elsif ($cached->type != $packet->type or $cached->size != $packet->size) {
            $first = 1;
        }
        elsif ($cached->timer != $packet->timer) {
            $first = 2;
        }
        else {
            $first = 3;
        }
    }

    if ($packet->number >= 0x140) {
        $io->write_u8( 1 | ($first << 6) );
        $io->write_u16( $packet->number - 0x40 );
    }
    elsif ($packet->number >= 0x40) {
        $io->write_u8( 0 | ($first << 6) );
        $io->write_u8( $packet->number - 0x40 );
    }
    else {
        $io->write_u8( ($packet->number & 0x3f) | ($first << 6) );
    }

    if ($first <= 2) {
        $io->write_u24( $packet->timer );
    }
    if ($first <= 1) {
        $io->write_u24( $packet->size );
        $io->write_u8( $packet->type );
    }
    if ($first <= 0) {
        $io->write( pack 'V', $packet->stream_id );
    }

    my $size = $packet->size;
    my $data_size = length $packet->data;

    if ($size <= $chunk_size) {
        $io->write( $packet->data );
    }
    else {
        for (my $cursor = 0; $cursor < $size; $cursor += $chunk_size) {
            my $rest = $size - $cursor;
            $rest = $chunk_size if $rest > $chunk_size;

            my $read = substr $packet->data, $cursor, $rest;

            $read .= pack 'C', $packet->number | 0xc0 if $cursor + length($read) < $size;
            $io->write($read);
        }
    }

    $self->write_packet_cache->[ $packet->number ] = Kamaitachi::Packet->new(
        number    => $packet->number,
        type      => $packet->type,
        timer     => $packet->timer,
        size      => $packet->size,
        stream_id => $packet->stream_id,
    );

    $io->data;
}

sub get_rtmp_packet {
    my ($self) = @_;

    my $first = $self->read_u8;
    return $self->reset unless defined $first;

    my $header_size = $first >> 6;
    my $number      = $first & 0x3f;

    if (0 == $number) {
        $number = $self->read_u8;
        return $self->reset unless defined $number;
        $number += 64;
    }
    elsif (1 == $number) {
        $number = $self->read_u16;
        return $self->reset unless defined $number;
        $number += 64;
    }

    my $packet = $self->read_packet_cache->[ $number ] || Kamaitachi::Packet->new(
        number => $number,
    );

    if ($packet->is_full) {
        $packet->data('');
        $packet->filled(0);
    }

    if ($header_size <= 2) {
        if ($header_size == 2 and !$packet->size) {
            warn 'Error: got invalid data...';
            $self->handle->push_shutdown;
            return;
        }

        my $timer = $self->read_u24;
        return $self->reset unless defined $timer;

        $packet->timer( $timer );
    }
    if ($header_size <= 1) {
        my $size = $self->read_u24;
        return $self->reset unless defined $size;

        $packet->size($size);

        my $type = $self->read_u8;
        return $self->reset unless defined $type;
        $packet->type($type);

        $packet->data('');
        $packet->filled(0);
    }
    if ($header_size <= 0) {
        my $stream_id = $self->read(4);
        return $self->reset unless defined $stream_id;

        $stream_id = unpack 'V', $stream_id;
        $packet->stream_id($stream_id);
    }

    my $rest = $packet->size - $packet->filled;
    if (0 < $rest) {
        if ($self->read_chunk_size < $rest) {
            $rest = $self->read_chunk_size;
        }

        my $data = $self->read($rest);
        return $self->reset unless defined $data;

        $packet->{data} .= $data;
        $packet->{filled} += $rest;
    }

    $packet->raw_data( $self->spin );
    $self->read_packet_cache->[ $number ] = $packet;

    $packet;
}

sub _build_handle {
    my ($self) = @_;
    AnyEvent::Handle->new( fh => $self->fh );
}

sub _build_buffer_length {
    my ($self) = @_;
    length $self->buffer;
}

sub _build_amf0_formatter {
    'Data::AMF::Formatter::AMF0';
}

sub _build_amf0_parser {
    'Data::AMF::Parser::AMF0';
}

__PACKAGE__->meta->make_immutable;

