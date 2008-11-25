package Kamaitachi::Service::AutoConnect;
use Moose::Role;

with 'Kamaitachi::Service::ConnectionHandler';

sub on_invoke_connect {
    my ($self, $session, $packet) = @_;
    $packet->response( $self->connect_success_response );
}

1;


