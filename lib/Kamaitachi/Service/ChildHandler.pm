package Kamaitachi::Service::ChildHandler;
use Moose::Role;

has child => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
);

before 'on_connect' => sub {
    my ($self, $session) = @_;
    $self->child->[ $session->id ] = $session;
};

after 'on_close' => sub {
    my ($self, $session) = @_;
    delete $self->child->[ $session->id ];
};

1;
