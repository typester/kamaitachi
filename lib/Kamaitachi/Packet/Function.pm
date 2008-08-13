package Kamaitachi::Packet::Function;
use Moose;

use Kamaitachi::Packet;

has method => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

has id => (
    is       => 'rw',
    isa      => 'Int',
    required => 1,
);

has args => (
    is      => 'rw',
    lazy    => 1,
    default => sub { {} },
);

has packet => (
    is       => 'rw',
    isa      => 'Object',
    weak_ref => 1,
);

has context => (
    is       => 'rw',
    isa      => 'Object',
    weak_ref => 1,
    lazy     => 1,
    default  => sub {
        my $self = shift;
        $self->packet->socket->context;
    },
);

__PACKAGE__->meta->make_immutable;

sub response {
    my ($self, $obj) = @_;

    Kamaitachi::Packet::Function->new(
        method => '_result',
        id     => $self->id,
        args   => $obj,
        packet => $self->packet,
    );
}

sub serialize {
    my $self = shift;

    my $parser = $self->context->parser;

    my $data = $parser->serialize($self->method);
    $data   .= $parser->serialize($self->id);
    $data   .= $parser->serialize({ });
    $data   .= $parser->serialize($self->args);

    my $packet = Kamaitachi::Packet->new(
        %{ $self->packet },
        size => bytes::length($data),
        data => $data,
    );

    $packet->serialize;
};

1;

