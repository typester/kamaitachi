package Kamaitachi::Service::NetStreamHandler;
use Moose::Role;

use Carp;
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
__END__

=encoding utf8

=head1 NAME

Kamaitachi::Service::NetStreamHandler - service role to create netstream packet

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 send_server_bw

=head2 send_client_bw

=head2 send_clear

=head2 send_status

=head1 SEE ALSO

L<Kamaitachi>,
L<Kamaitachi::Service>

=head1 AUTHOR

Daisuke Murase <typester@cpan.org>

Hideo Kimura <hide@cpan.org>

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
