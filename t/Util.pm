package t::Util;
use strict;
use warnings;
use base qw/Exporter/;

our @EXPORT = qw/start_server stop_server/;

sub start_server {
    my $port = shift;

    my $pid = fork;
    if ($pid) {
        return $pid;
    }
    elsif ($pid == 0) {
        Kamaitachi->new( port => $port )->run;
    }
    else {
        die 'fork failed'
    }
}

sub stop_server($) {
    my $pid = shift;
    kill 9, $pid;
}

1;

