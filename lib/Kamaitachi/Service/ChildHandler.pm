package Kamaitachi::Service::ChildHandler;
use Any::Moose '::Role';

has child => (
    is      => 'rw',
    default => sub { [] },
);

before 'on_connect' => sub {
    my ($self, $session) = @_;
    $self->child->[ $session->id ] = $session;
};

after 'on_close' => sub {
    my ($self, $session) = @_;
    delete $self->child->[ $session->id ];
};

1;

__END__

=encoding utf8

=head1 NAME

Kamaitachi::Service::ChildHandler - service role to handle clients

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

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
