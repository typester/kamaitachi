package Kamaitachi::ConnectionHandler;
use Any::Moose;

use AnyEvent::Socket;
use Scalar::Util;

use MIME::Base64::URLSafe;
use Data::UUID;

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

has ug => (
    is         => 'rw',
    lazy_build => 1,
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
        my $id      = urlsafe_b64encode($self->ug->create);

        my $session = Kamaitachi::Session->new(
            id      => $id,
            fh      => $fh,
            proto   => $self->proto,
            context => $context,
        );
        $context->add_session($session);
    };
    Scalar::Util::weaken($self);
    $self->connection_guard($guard);
}

sub _build_ug {
    my ($self) = @_;
    Data::UUID->new;
}

__PACKAGE__->meta->make_immutable;

