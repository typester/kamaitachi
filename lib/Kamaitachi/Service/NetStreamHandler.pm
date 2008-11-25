package Kamaitachi::Service::NetStreamHandler;
use Moose::Role;

use Kamaitachi::Packet;

with 'Kamaitachi::Service::AMFHandler';

sub net_stream_status {
    my ($self, $response) = @_;

    confess 'require response' unless $response;
    $response = { code => $response } unless ref $response;

    $response->{level}       ||= 'status';
    $response->{description} ||= '-';
    $response->{clientid}    ||= 1;

    Kamaitachi::Packet->new(
        number => 4,
        type   => 0x14,
        obj    => 0x01000000,
        data   => $self->parser->serialize(
            'onStatus', 1, undef, $response,
        ),
    );
}

1;

