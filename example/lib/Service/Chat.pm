package Service::Chat;
use Moose;

extends 'Kamaitachi::Service';

with qw/Kamaitachi::Service::AutoConnect
        Kamaitachi::Service::Broadcaster
       /;

sub on_invoke_send {
    my ($self, $session, $req) = @_;

    my $msg = $req->args->[1];
    my $res = $self->broadcast_notify_packet( onMessage => $msg );

    $self->broadcast( $session => $res );

    return $req->response;      # return null response
}

__PACKAGE__->meta->make_immutable;
