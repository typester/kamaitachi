#!/usr/bin/env perl

use strict;
use warnings;
use FindBin::libs;

use Kamaitachi;

{
    package Service::Echo;
    use base 'Kamaitachi::Service';

    sub on_method_connect {
        my ($self, $session, $arg) = @_;

        $arg->{function}->response(undef, {
            level       => 'status',
            code        => 'NetConnection.Connect.Success',
            description => 'Connection succeeded.',
        });
    }

    sub on_method_echo {
        my ($self, $session, $arg) = @_;

        my $fn = $arg->{function};
        $fn->response( $fn->args );
    }
}

my $kamaitachi = Kamaitachi->new;
$kamaitachi->register_services(
    '*' => 'Service::Echo',
);

$kamaitachi->run;
