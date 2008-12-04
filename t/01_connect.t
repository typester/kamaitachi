use Test::Base;
use Test::TCP;

plan tests => 2;

use t::Client;

use Kamaitachi;

my $port = empty_port;

my $k = Kamaitachi->new( port => $port );

use constant {
    CONNECT   => 0,
    HANDSHAKE => 1,
};

my $state = CONNECT;

# connect
create_client(
    $port,
    {
        on_write_ready => sub {
            my $socket = shift;
            pass("connect success");

            my $packet = $socket->{context}{client_token} = pack('C', 0) x 0x600;

            $socket->watch_write(0);
            $socket->write(
                pack('C', 3) . pack('C', 0) x 0x600,
            );

            $state = HANDSHAKE;
        },

        on_read_ready => sub {
            my $socket = shift;

            my $bref = $socket->read( $k->buffer_size );
            unless (defined $bref) {
                $socket->close;
                stop_loop;
                return;
            }
            $socket->{context}{io}->push($$bref);

            if ($state == CONNECT) {
                fail("handshake ok");
                stop_loop;
                return;
            }

            if ($state == HANDSHAKE) {
                if (not $socket->{context}{server_token}) {
                    $bref = $socket->{context}{io}->read(0x600 + 1) or return;
                    $socket->{context}{server_token} = substr $$bref, 1;
                }

                if ($socket->{context}{server_token}) {
                    $bref = $socket->{context}{io}->read(0x600) or return;
                    my $token = $$bref;

                    is($socket->{context}{client_token}, $token, 'handshake ok');

                    $socket->close;
                    stop_loop;
                }
            }
        },
    },
);
run_loop;
