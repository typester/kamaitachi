package Kamaitachi::Service::ConnectionHandler;
use Any::Moose '::Role';

sub connect_success_response {
    return(
        {
            fmsVer       => 'kamaitachi/' . $Kamaitachi::VERSION,
            capabilities => 31,
        },
        {
            level       => 'status',
            code        => 'NetConnection.Connect.Success',
            description => 'Connection succeeded.',
        }
    );
}

sub connect_reject_response {
    my ($self, $reason) = @_;

    return(
        undef, {
            level       => 'status',
            code        => 'NetConnection.Connect.Rejected',
            description => $reason || '-',
        }
    );
}

1;

__END__

=head1 NAME

Kamaitachi::Service::ConnectionHandler - service role to create connect response

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 connect_success_response

=head2 connect_reject_response

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

