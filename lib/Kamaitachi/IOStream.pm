package Kamaitachi::IOStream;
use Moose;

use constant ENDIAN => unpack('S', pack('C2', 0, 1)) == 1 ? 'BIG' : 'LITTLE';

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

has buffer_length => (
    is      => 'rw',
    isa     => 'Int',
    default => sub { 0 },
);

has cursor => (
    is      => 'rw',
    isa     => 'Int',
    default => sub { 0 },
);

__PACKAGE__->meta->make_immutable;

sub push {
    my ($self, $data) = @_;

    $self->{buffer} .= $data;
    $self->{buffer_length} = bytes::length($self->buffer);
}

sub reset {
    my $self = shift;

    $self->cursor(0);
    return;
}

sub spin {
    my $self = shift;

    my $read        = substr $self->buffer, 0, $self->cursor;
    $self->{buffer} = substr $self->buffer, $self->cursor;
    $self->buffer_length( bytes::length($self->buffer) );
    $self->cursor(0);

    $read;
}

sub clear {
    my $self = shift;
    $self->buffer(q[]);
    $self->buffer_length(0);
    $self->cursor(0);
}

sub read {
    my ($self, $len) = @_;

    return if $self->buffer_length < ($self->cursor + $len);

    my $data = substr $self->buffer, $self->cursor, $len;
    $self->{cursor} += $len;

    \$data;
}

sub read_u8 {
    my $self = shift;

    my $bref = $self->read(1) or return;
    \unpack('C', $$bref);
}

sub read_u16 {
    my $self = shift;

    my $data = $self->read(2) or return;
    \unpack('n', $$data);
}

sub read_s16 {
    my $self = shift;

    my $data = $self->read(2) or return;

    return \unpack('s>', $$data) if $] >= 5.009002;
    return \unpack('s', $$data)  if ENDIAN eq 'BIG';
    return \unpack('s', swap($$data));
}

sub read_u24 {
    my $self = shift;

    my $data = $self->read(3) or return;
    \unpack('N', "\0".$$data);
}

sub read_u32 {
    my $self = shift;

    my $data = $self->read(4) or return;
    \unpack('N', $$data);
}

sub read_double {
    my $self = shift;

    my $data = $self->read(8) or return;

    return \unpack('d>', $$data) if $] >= 5.009002;
    return \unpack('d', $$data)  if ENDIAN eq 'BIG';
    return \unpack('d', swap($$data));
}

sub read_utf8 {
    my $self = shift;

    my $len = $self->read_u16 or return;
    my $bref = $self->read($len) or return;
}

sub read_utf8_long {
    my $self = shift;

    my $len = $self->read_u32 or return;
    my $bref = $self->read($len) or return;
}

sub write {
    my ($self, $data) = @_;

    if (ref $data) {
        confess qq{Can't write this object: "@{[ ref $data ]}"} unless $data->can('serialize');
        $data = $data->serialize;
    }

    $self->socket->write($data);
}

sub get_packet {
    my ($self, $chunk_size, $packet_list) = @_;
    my $bref;

    $chunk_size  ||= 128;
    $packet_list ||= [];

    $bref = $self->read_u8 or return $self->reset;
    my $first = $$bref;

    my $header_size = $first >> 6;
    my $amf_number  = $first & 0x3f;

    if ($amf_number == 0) {
        $bref = $self->read_u8 or return $self->reset;
        $amf_number = $$bref;
    }
    elsif ($amf_number == 1) {
        $bref = $self->read_u16 or return $self->reset;
        $amf_number = $$bref;
    }

    my $packet = $packet_list->[ $amf_number ] || Kamaitachi::Packet->new( socket => $self->socket, number => $amf_number );

    if ($header_size <= 2) {
        $bref = $self->read_u24 or return $self->reset;
        $packet->timer( $$bref );
        $packet->partial(1);
    }
    if ($header_size <= 1) {
        $bref = $self->read_u24 or return $self->reset;
        $packet->size( $$bref );
        $bref = $self->read_u8 or return $self->reset;
        $packet->type( $$bref );

        $packet->data(q[]);
        $packet->raw(q[]);
        $packet->partial(0);
    }
    if ($header_size <= 0) {
        $bref = $self->read_u32 or return $self->reset;
        $packet->obj( $$bref );
    }

    my $data = q[];
    my $size = $packet->size;

    if ($packet->data and bytes::length($packet->data) < $size) {
        $data = $packet->data;
        $size -= bytes::length($packet->data);
    }

    if ($size > 0) {
        my $want = $size <= $chunk_size ? $size : $chunk_size;

        $bref = $self->read($want) or return $self->reset;
        $data .= $$bref;
    }

    $packet->data($data);
    $packet->{raw} = $self->spin;

    $packet_list->[ $amf_number ] = $packet;

    $packet;
}

1;

