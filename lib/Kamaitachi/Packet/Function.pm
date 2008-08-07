package Kamaitachi::Packet::Function;
use Moose;

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
    isa     => 'HashRef',
    lazy    => 1,
    default => sub { {} },
);

has packet => (
    is       => 'rw',
    isa      => 'Object',
    weak_ref => 1,
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

    
}

1;

