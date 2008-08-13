package Kamaitachi::Packet;
use Moose;
require bytes;

use Kamaitachi::Packet::Function;

has number => (
    is  => 'rw',
    isa => 'Int',
);

has timer => (
    is  => 'rw',
    isa => 'Int',
);

has size => (
    is  => 'rw',
    isa => 'Int',
);

has type => (
    is  => 'rw',
    isa => 'Int',
);

has obj => (
    is => 'rw',
);

has data => (
    is  => 'rw',
    isa => 'Str',
);

has socket => (
    is       => 'rw',
    isa      => 'Object',
    weak_ref => 1,
);


__PACKAGE__->meta->make_immutable;

sub serialize {
    my $self = shift;

    my $data = q[];

    if ($self->number > 255) {
        $data = pack('C', 0 & 0x3f);
        $data .= pack('n', $self->number);
    }
    elsif ($self->number > 63) {
        $data = pack('C', 1 & 0x3f);
        $data .= pack('C', $self->number);
    }
    else {
        $data = pack('C', $self->number & 0x3f);
    }

    $data .= reverse pack('CCC', $self->timer);
    $data .= reverse pack('CCC', $self->size);
    $data .= pack('C', $self->type);
    $data .= pack('N', $self->obj);

    my $socket     = $self->socket;
    my $chunk_size = $socket->session->chunk_size;

    if ($self->size <= $chunk_size) {
        $data .= $self->data;
    }
    else {
        for (my $cursor = 0; $cursor < $self->size; $cursor += $chunk_size) {
            my $read = substr $self->data, $cursor, $chunk_size;
            $read .= pack('C', 0xc3) if bytes::length($read) == $chunk_size;

            $data .= $read;
        }
    }

    $data;
}

sub function {
    my $self = shift;

    my ($method, $id, $args) = $self->socket->context->parser->deserialize($self->data);

    Kamaitachi::Packet::Function->new(
        method => $method,
        id     => $id,
        args   => $args,
        packet => $self,
    );
}

1;

