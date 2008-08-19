package Kamaitachi::Packet;
use Moose;
require bytes;

use Data::AMF::IO;
use Kamaitachi::Packet::Function;

has number => (
    is  => 'rw',
    isa => 'Int',
);

has timer => (
    is      => 'rw',
    isa     => 'Int',
    lazy    => 1,
    default => sub { 0 },
);

has size => (
    is      => 'rw',
    isa     => 'Int',
    lazy    => 1,
    default => sub {
        my $self = shift;
        bytes::length($self->data);
    },
);

has type => (
    is  => 'rw',
    isa => 'Int',
);

has obj => (
    is      => 'rw',
    lazy    => 1,
    default => sub { 0 },
);

has data => (
    is  => 'rw',
    isa => 'Str',
);

has raw => (
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
    my ($self, $chunk_size) = @_;
    $chunk_size ||= 128;

    my $io = Data::AMF::IO->new( data => q[] );

    if ($self->number > 255) {
        $io->write_u8( 0 & 0x3f );
        $io->write_u16( $self->number );
    }
    elsif ($self->number > 63) {
        $io->write_u8( 1 & 0x3f );
        $io->write_u8( $self->number );
    }
    else {
        $io->write_u8( $self->number & 0x3f );
    }

    $io->write_u24( $self->timer );
    $io->write_u24( $self->size );
    $io->write_u8( $self->type );
    $io->write_u32( $self->obj );

    if ($self->size <= $chunk_size) {
        $io->write( $self->data );
    }
    else {
        for (my $cursor = 0; $cursor < $self->size; $cursor += $chunk_size) {
            my $read = substr $self->data, $cursor, $chunk_size;
            $read .= pack('C', 0xc3) if $cursor + bytes::length($read) < $self->size;

            $io->write( $read );
        }
    }

    $io->data;
}

sub function {
    my $self = shift;

    my ($method, $id, @args) = $self->socket->context->parser->deserialize($self->data);

    Kamaitachi::Packet::Function->new(
        method => $method,
        id     => $id,
        args   => \@args,
        packet => $self,
    );
}

1;

