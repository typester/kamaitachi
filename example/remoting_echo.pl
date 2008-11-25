#!/usr/bin/env perl

use strict;
use warnings;
use FindBin::libs;

use Kamaitachi;

{
    package Service::Echo;
    use Moose;

    extends 'Kamaitachi::Service';

    with 'Kamaitachi::Service::AutoConnect';

    sub on_invoke_echo {
        my ($self, $session, $req) = @_;
        $req->response(@{ $req->args });
    }
}

my $kamaitachi = Kamaitachi->new;
$kamaitachi->register_services(
    '*' => 'Service::Echo',
);
$kamaitachi->run;
