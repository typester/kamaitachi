package Kamaitachi::Service::NetStreamHandler;
use Moose::Role;

use Kamaitachi::Packet;

with 'Kamaitachi::Service::AMFHandler';

sub send_server_bw {
    my ( $self, $session, $response ) = @_;

    $session->io->write(
        Kamaitachi::Packet->new(
            number => 2,
            type   => 0x05,
            data   => pack( 'N', 2500000 ),
        )
    );
}

sub send_client_bw {
    my ( $self, $session, $response ) = @_;

    $session->io->write(
        Kamaitachi::Packet->new(
            number => 2,
            type   => 0x06,
            data   => pack( 'N', 2500000 ) . pack( 'C', 2 ),
        )
    );
}

sub send_clear {
    my ( $self, $session ) = @_;

    $session->io->write(
        Kamaitachi::Packet->new(
            number => 2,
            type   => 0x04,
            data   => "\0" x 6,
        )
    );
}

sub send_status {
    my ( $self, $session, $response ) = @_;

    confess 'require response' unless $response;
    $response = { code => $response } unless ref $response;

    $response->{level}       ||= 'status';
    $response->{description} ||= '-';
    $response->{clientid}    ||= 1;

    $session->io->write(
        Kamaitachi::Packet->new(
            number => 4,
            type   => 0x14,
            obj    => 0x01000000,
            data =>
                $self->parser->serialize( 'onStatus', 1, undef, $response, ),
        )
    );
}

1;

