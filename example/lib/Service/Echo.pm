package Service::Echo;
use Moose;

extends 'Kamaitachi::Service';

with 'Kamaitachi::Service::AutoConnect';

sub on_invoke_echo {
    my ($self, $session, $req) = @_;
    $req->response(@{ $req->args });
}

1;


