#!/usr/bin/env perl

use strict;
use warnings;

use FindBin::libs;
use lib "$FindBin::Bin/lib";

use Kamaitachi;

my $kamaitachi = Kamaitachi->new;

$kamaitachi->register_services(
    'rpc/echo'    => 'Service::Echo',
    'rpc/chat'    => 'Service::Chat',
    'stream/live' => 'Service::LiveStreaming',
);

$kamaitachi->run;

