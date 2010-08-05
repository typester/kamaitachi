package Kamaitachi::Packet::Function;
use Any::Moose;

extends 'Kamaitachi::Packet';

has [qw/id method/] => (
    is => 'rw',
);

has args => (
    is      => 'rw',
    default => sub { [] },
);

no Any::Moose;

sub result {
    my ($self, @obj) = @_;

    Kamaitachi::Packet::Function->new(
        %$self,
        method => '_result',
        args   => \@obj,
    );
}

sub error {
    my ($self, @obj) = @_;

    Kamaitachi::Packet::Function->new(
        %$self,
        method => '_error',
        args   => \@obj,
    );
}

__PACKAGE__->meta->make_immutable;
