use Test::Base;
use Test::TCP;

plan tests => 1;

use t::Util;
use t::Client;

use Kamaitachi;
use Danga::Socket;

my $port = empty_port;
my $pid  = start_server($port);
END { stop_server($pid) };

# connect
create_client(
    $port,
    {
        on_write_ready => sub {
            my $socket = shift;
            pass("connect success");
            $socket->close;
            stop_loop;
        },
    },
);
run_loop;
