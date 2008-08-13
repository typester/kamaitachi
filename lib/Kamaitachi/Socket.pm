package Kamaitachi::Socket;
use strict;
use warnings;
use base 'Danga::Socket::Callback';

use fields qw/session buffer io/;

use Kamaitachi::IOStream;

sub new {
    my $self = fields::new(shift);
    my %args = @_;

    $self->SUPER::new(%args);

    $self->{io}      = Kamaitachi::IOStream->new( socket => $self );
    $self->{session} = $args{session};
    $self->{buffer}  = q[];

    $self;
}

sub io      { $_[0]->{io} }
sub context { $_[0]->{context} }
sub session { $_[0]->{session} }

sub read {
    my $self = shift;
    my $bref = $self->SUPER::read(@_);

    unless (defined $bref) {
        $self->close;
        return;
    }

    $bref;
}

sub read_bytes {
    my ($self, $bytes) = @_;

    my $res = q[];

    if (length($self->{buffer}) >= $bytes) {
        $res = substr $self->{buffer}, 0, $bytes;
        $self->{buffer} = substr $self->{buffer}, $bytes;
        return $res;
    }

    my $bref = $self->read($bytes - length($self->{buffer})) or return;

    $res = $self->{buffer} . $$bref;
    if (length($res) == $bytes) {
        $self->{buffer} = q[];
        return $res;
    }
    else {
        $self->{buffer} .= $$bref;
        return;
    }
}

sub DESTROY {
    my $self = shift;
    $self->session->destroy;
}

1;
