package Service::Echo;
use Any::Moose;

extends 'Kamaitachi::Service';

with 'Kamaitachi::Service::AutoConnect';

no Any::Moose;

sub on_invoke_echo {
    my ($self, $session, $req) = @_;
    $req->result(@{ $req->args });
}

__PACKAGE__->meta->make_immutable;
