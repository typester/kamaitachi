package Kamaitachi::Socket;
use strict;
use warnings;
use base 'Danga::Socket::Callback';

use fields qw/session buffer io reading readback/;

use Kamaitachi::IOStream;

=head1 NAME

Kamaitachi::Socket - Kamaitachi connection socket

=head1 DESCRIPTION

See L<Kamaitachi>.

=head1 METHODS

=head2 new

=cut

sub new {
    my $self = fields::new(shift);
    my %args = @_;

    $self->SUPER::new(%args);

    $self->{session}     = $args{session};
    $self->{session}{io} = Kamaitachi::IOStream->new( socket => $self );
    $self->{buffer}  = q[];

    $self->{reading}  = 0;
    $self->{readback} = q[];

    $self;
}

=head2 context

=head2 session

=head2 closed

=cut

sub context { $_[0]->{context} }
sub session { $_[0]->{session} }
sub closed  { $_[0]->{closed} }

=head2 close

=cut

sub close {
    my $self = shift;
    $self->session->close(@_);
    $self->SUPER::close(@_);
}

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
