package Kamaitachi::Service::AutoConnectACL;
use Moose::Role;
use Text::Glob qw/glob_to_regex/;

with 'Kamaitachi::Service::AutoConnect';

requires 'allow_pages', 'allow_swfs';

around on_invoke_connect => sub {
    my $next = shift;
    my ($self, $session, $req) = @_;

    local $Text::Glob::strict_leading_dot = 0;
    local $Text::Glob::strict_wildcard_slash = 0;

    my $connect_info = $req->args->[0];

    my $allow_page;
    for my $page ($self->allow_pages) {
        $page = glob_to_regex($page) unless ref $page eq 'Regexp';
        if ($connect_info->{pageUrl} =~ $page) {
            $allow_page++;
            last;
        }
    }

    my $allow_swf;
    for my $swf ($self->allow_swfs) {
        $swf = glob_to_regex($swf) unless ref $swf eq 'Regexp';
        if ($connect_info->{swfUrl} =~ $swf) {
            $allow_swf++;
            last;
        }
    }

    if ($allow_page && $allow_swf) {
        $next->(@_);
    }
    else {
        my $res = $req->response(undef, {
            level       => 'error',
            code        => 'NetConnection.Connect.Rejected',
            description => '-',
        });
        $session->io->write( $res );
        $session->io->close;
    }
};

=head1 NAME

Kamaitachi::Service::AutoConnectACL - service role to accept connection with ACL

=head1 SYNOPSIS

=head1 DESCRIPTION

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

1;

