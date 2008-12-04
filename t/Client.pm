package t::Client;
use strict;
use warnings;
use base qw/Exporter/;

our @EXPORT = qw/create_client run_loop stop_loop/;

use IO::Handle;
use IO::Socket::INET;
use Socket qw/IPPROTO_TCP TCP_NODELAY SOCK_STREAM/;
use Danga::Socket::Callback;

sub create_client {
    my $port     = shift;
    my $callback = shift;

    my $socket = IO::Socket::INET->new(
        PeerAddr => "127.0.0.1:$port",
        Type     => SOCK_STREAM,
        Blocking => 0,
    );
    IO::Handle::blocking($socket, 0);

    Danga::Socket::Callback->new(
        handle  => $socket,
        context => { buf => q[] },
        %{ $callback || {} },
    );
}

sub run_loop() {
    Danga::Socket->EventLoop;
}

sub stop_loop() {
    Danga::Socket->SetPostLoopCallback(sub { 0 });
}

1;

