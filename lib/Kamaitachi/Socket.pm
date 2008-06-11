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
}

1;
