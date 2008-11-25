#!/usr/bin/env perl

use strict;
use warnings;
use FindBin::libs;

use Kamaitachi;

{
    package Service::Streaming;
    use Moose;

    extends 'Kamaitachi::Service';

    with 'Kamaitachi::Service::AutoConnect',
         'Kamaitachi::Service::Streaming';
}

my $kamaitachi = Kamaitachi->new;
$kamaitachi->register_services(
    '*' => 'Service::Streaming',
);

$kamaitachi->run;
