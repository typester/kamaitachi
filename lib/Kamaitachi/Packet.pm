package Kamaitachi::Packet;
use Any::Moose;

has number => (
    is       => 'rw',
    required => 1,
);

has [qw/type data raw_data/] => (
    is => 'rw',
);

has [qw/timer stream_id size filled/] => (
    is      => 'rw',
    default => 0,
);

has size => (
    is      => 'rw',
    lazy    => 1,
    default => sub { defined $_[0]->data ? length($_[0]->data) : 0 },
);

no Any::Moose;

sub is_full {
    my ($self) = @_;
    $self->size > 0 && $self->size == $self->filled;
}

__PACKAGE__->meta->make_immutable;
