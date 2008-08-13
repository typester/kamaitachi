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

__PACKAGE__->meta->make_immutable;

sub read {
    my ($self, $len) = @_;
    $self->socket->read_bytes( $len );
}

sub write {
    my ($self, $data) = @_;
    $self->socket->write($data);
}

sub get_packet {
    my $self = shift;

    my $first = $self->read_u8 or return;

    my $header_size = $first >> 6;
    my $amf_number  = $first & 0x3f;

    if ($amf_number == 0) {
        $amf_number = $self->read_u8;
    }
    elsif ($amf_number == 1) {
        $amf_number = $self->read_u16;
    }

    my $packet = $self->socket->session->packets->[ $amf_number ]
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
    my $chunk_size = $self->socket->session->chunk_size;

    if ($size <= $chunk_size) {
        $data = $self->read($size);
    }
    else {
        my $read = $chunk_size;
        $data .= $self->read($chunk_size);

        while ($read < $size) {
            $self->read(1);

            my $rest  = $size - $read;
            my $bytes = $rest > $chunk_size ? $chunk_size : $rest;

            $data .= $self->read($bytes) or confess;
            $read += $bytes;
        }
    }
    $packet->data( $data );

    $packet;
}

1;

