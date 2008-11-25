package Kamaitachi::Service::AMFHandler;
use Moose::Role;

use Data::AMF;

has parser => (
    is      => 'rw',
    isa     => 'Object',
    default => sub { Data::AMF->new },
);

1;

