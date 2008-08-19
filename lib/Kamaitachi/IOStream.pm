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

__PACKAGE__->meta->make_immutable;

sub read {
    my ($self, $len) = @_;
    $self->socket->read_bytes($len);
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
    $self->socket->write($data);
}

sub get_packet {
    my ($self, $chunk_size, $packet_list) = @_;
    my $bref;

    $chunk_size  ||= 128;
    $packet_list ||= [];

    $self->socket->start_read;

    $bref = $self->read_u8 or return;
    my $first = $$bref;

    my $header_size = $first >> 6;
    my $amf_number  = $first & 0x3f;

    if ($amf_number == 0) {
        $bref = $self->read_u8 or return;
        $amf_number = $$bref;
    }
    elsif ($amf_number == 1) {
        $bref = $self->read_u16 or return;
        $amf_number = $$bref;
    }

    my $packet = $packet_list->[ $amf_number ] || Kamaitachi::Packet->new( socket => $self->socket, number => $amf_number );

    if ($header_size <= 2) {
        $bref = $self->read_u24 or return;
        $packet->timer( $$bref );
    }
    if ($header_size <= 1) {
        $bref = $self->read_u24 or return;
        $packet->size( $$bref );
        $bref = $self->read_u8 or return;
        $packet->type( $$bref );
    }
    if ($header_size <= 0) {
        $bref = $self->read_u32 or return;
        $packet->obj( $$bref );
    }

    my $data = q[];
    my $size = $packet->size;

    if ($size > 0) {
        if ($size <= $chunk_size) {
            $bref = $self->read($size) or return;
            $data = $$bref;
        }
        else {
            my $read = $chunk_size;
            $bref = $self->read($chunk_size) or return;
            $data .= $$bref;

            while ($read < $size) {
                my $c3 = $self->read(1) or return;

                my $rest  = $size - $read;
                my $bytes = $rest > $chunk_size ? $chunk_size : $rest;

                $bref = $self->read($bytes) or return;
                $data .= $$bref;
                $read += $bytes;
            }
        }
    }
    $packet->data($data);

    $packet->raw( $self->socket->{readback} );

    $self->socket->end_read;

    $packet_list->[ $amf_number ] = $packet;

    $packet;
}

1;

