package Kamaitachi::IOStream;
use Moose;

extends 'Data::AMF::IO';

use Kamaitachi::Packet;

has socket => (
    is       => 'rw',
    isa      => 'Object',
    weak_ref => 1,
    required => 1,
);

has buffer => (
    is      => 'rw',
    isa     => 'Str',
    default => sub { q[] },
);

has has_buffer => (
    is      => 'rw',
    isa     => 'Int',
    default => sub { 0 },
);

__PACKAGE__->meta->make_immutable;

sub read {
    my ($self, $len) = @_;

    my $data;

    if ($self->has_buffer) {
        if (length($self->buffer) < $len) {
            my $add = $self->socket->read_bytes( $len - length($self->buffer) );
            $self->add_buffer($add);

            return if length($self->buffer) < $len;
        }

        $data = substr $self->buffer, 0, $len;
        $self->buffer( substr $self->buffer, $len );
    }
    else {
        $data = $self->socket->read_bytes( $len );
        $self->add_buffer($data);
    }

    $data;
}

sub write {
    my ($self, $data) = @_;
    $self->socket->write($data);
}

sub add_buffer {
    my ($self, $data) = @_;
    $self->{buffer} .= $data if defined $data;
}

sub clear_buffer {
    my $self = shift;
    $self->has_buffer(0);
    $self->buffer(q[]);
}

sub get_packet {
    my ($self, $chunk_size, $packet_list) = @_;
    $chunk_size  ||= 128;
    $packet_list ||= [];

    my $first = $self->read_u8 or return;

    my $header_size = $first >> 6;
    my $amf_number  = $first & 0x3f;

    if ($amf_number == 0) {
        $amf_number = $self->read_u8;
    }
    elsif ($amf_number == 1) {
        $amf_number = $self->read_u16;
    }

    my $packet = $packet_list->[ $amf_number ]
                 ||= Kamaitachi::Packet->new( socket => $self->socket, number => $amf_number );

    if ($header_size <= 2) {
        $packet->timer( $self->read_u24 );
    }
    if ($header_size <= 1) {
        $packet->size( $self->read_u24 );
        $packet->type( $self->read_u8 );
    }
    if ($header_size <= 0) {
        $packet->obj( $self->read_u32 );
    }

    my $data = q[];
    my $size = $packet->size;

    if ($size <= $chunk_size) {
        $data = $self->read($size);
    }
    else {
        my $read = $chunk_size;
        $data .= $self->read($chunk_size);

        while ($read < $size) {
            my $c3 = $self->read(1);

            my $rest  = $size - $read;
            my $bytes = $rest > $chunk_size ? $chunk_size : $rest;

            my $received = $self->read($bytes);
            unless (defined $received) {
                $self->has_buffer(1);
                return;
            }

            $data .= $received;
            $read += $bytes;
        }
    }
    $packet->data( $data );
    $packet->raw( $self->buffer );

    $self->clear_buffer;

    $packet;
}

1;

