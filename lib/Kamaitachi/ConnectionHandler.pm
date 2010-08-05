package Kamaitachi::ConnectionHandler;
use Any::Moose;

use AnyEvent::Socket;
use Scalar::Util;

use Kamaitachi::Session;

has host => (
    is      => 'rw',
    default => '0.0.0.0',
);

has port => (
    is      => 'rw',
    default => 1935,
);

has proto => (
    is      => 'rw',
    default => 'rtmp',
);

has context => (
    is       => 'rw',
    weak_ref => 1,
);

has connection_guard => (
    is => 'rw',
);

no Any::Moose;

sub BUILD {
    my ($self) = @_;

    my $guard = tcp_server $self->host, $self->port, sub {
        my ($fh) = @_
            or die "Accept failed: $!";

        my $context = $self->context;
        my $session = Kamaitachi::Session->new(
            fh      => $fh,
            proto   => $self->proto,
            context => $context,
        );
        $context->sessions->[fileno $fh] = $session;
    };
    Scalar::Util::weaken($self);
    $self->connection_guard($guard);
}

__PACKAGE__->meta->make_immutable;

