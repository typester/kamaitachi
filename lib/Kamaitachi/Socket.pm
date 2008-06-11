package Kamaitachi::Socket;
use strict;
use warnings;
use base 'Danga::Socket::Callback';

use fields qw/
                 handshaked
                 client_handshake_packet
                 server_handshake_packet

                 buffer
             /;

sub new {
    my $self = fields::new(shift);
    $self->SUPER::new(@_);

    $self->{buffer} = q[];
    $self;
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

    my $bref = $self->read($bytes - length($self->{buffer})) or return;

    my $res = $self->{buffer} . $$bref;

    if (length($res) == $bytes) {
        $self->{buffer} = q[];
        return \$res;
    }
    else {
        $self->{buffer} .= $$bref;
        return;
    }
}

1;
