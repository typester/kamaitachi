package Kamaitachi::Packet::Function;
use Moose;

use Data::AMF;

extends 'Kamaitachi::Packet';

has method => (
    is       => 'rw',
    isa      => 'Str',
);

has id => (
    is       => 'rw',
    isa      => 'Int',
);

has args => (
    is      => 'rw',
    isa     => 'ArrayRef',
    lazy    => 1,
    default => sub { [] },
);

has parser => (
    is      => 'rw',
    isa     => 'Object',
    lazy    => 1,
    default => sub {
        Data::AMF->new;
    }
);

no Moose;

sub new_from_packet {
    my $class = shift;
    my $args  = @_ > 1 ? {@_} : $_[0];

    my $packet = $args->{packet}
        or confess 'require packet';

    my $self = $class->new(
        %$packet,
        %$args,
    );

    my ($method, $id, @args);
    eval {
        ($method, $id, @args) = $self->parser->deserialize($packet->data);
    };
    if ($@) {
        return;
    }

    $self->{method} = $method;
    $self->{id}     = $id;
    $self->{args}   = \@args;

    $self;
}

sub response {
    my ($self, @obj) = @_;

    Kamaitachi::Packet::Function->new(
        %$self,
        method => '_result',
        args   => \@obj,
    );
}

sub serialize {
    my $self = shift;

    my $data = $self->parser->serialize(
        $self->method,
        $self->id,
        @{ $self->args },
    );

    my $packet = Kamaitachi::Packet->new(
        %$self,
        size => bytes::length($data),
        data => $data,
    );

    $packet->serialize(@_);
};

1;
