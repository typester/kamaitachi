package Kamaitachi::IO::RTMPT;
use Any::Moose;

extends 'Kamaitachi::IO';

use HTTP::Parser::XS qw(parse_http_request);
use HTTP::Response;

use MIME::Base64::URLSafe;
use Data::UUID;

no Any::Moose;

sub handle_client_handshaking {
    my ($self, %callbacks) = @_;

    warn 'HMMMMMMM';
}

__PACKAGE__->meta->make_immutable;

