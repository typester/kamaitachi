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

    $self->{io}      = Kamaitachi::IOStream->new( socket => $self );
    $self->{session} = $args{session};
    $self->{buffer}  = q[];

    $self->{reading}  = 0;
    $self->{readback} = q[];

    $self;
}

sub io      { $_[0]->{io} }
sub context { $_[0]->{context} }
sub session { $_[0]->{session} }

sub start_read {
    my $self = shift;

    if ($self->{readback}) {
        $self->{buffer} = $self->{readback} . $self->{buffer};
        $self->{readback} = q[];
    }

    $self->{reading} = 1;
}

sub end_read {
    my $self = shift;
    $self->{readback} = q[];
    $self->{reading} = 0;
}

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
        $self->{readback} .= $res if $self->{reading};
        return \$res;
    }

    my $bref = $self->read($bytes - length($self->{buffer})) or return;

    $res = $self->{buffer} . $$bref;

    if (length($res) > $bytes) {
        $self->{buffer} = substr $res, $bytes;
        $res = substr $res, 0, $bytes;
        $self->{readback} .= $res if $self->{reading};
        return \$res;
    }
    elsif (length($res) == $bytes) {
        $self->{buffer} = q[];
        $self->{readback} .= $res if $self->{reading};
        return \$res;
    }
    else {
        $self->{buffer} = $res;
        return;
    }
}

sub DESTROY {
    my $self = shift;
    $self->session->destroy;
}

1;
