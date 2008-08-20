package Kamaitachi::Socket;
use strict;
use warnings;
use base 'Danga::Socket::Callback';

use fields qw/session buffer io reading readback/;

use Kamaitachi::IOStream;

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

sub context { $_[0]->{context} }
sub session { $_[0]->{session} }

sub DESTROY {
    my $self = shift;
    $self->session->destroy;
}

1;
