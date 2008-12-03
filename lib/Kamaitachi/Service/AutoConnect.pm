package Kamaitachi::Service::AutoConnect;
use Moose::Role;

with 'Kamaitachi::Service::ConnectionHandler';

sub on_invoke_connect {
    my ($self, $session, $packet) = @_;
    $packet->response( $self->connect_success_response );
}

1;

__END__

=encoding utf8

=head1 NAME

Kamaitachi::Service::AutoConnect - service role to accept all connection

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 on_invoke_connect

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
