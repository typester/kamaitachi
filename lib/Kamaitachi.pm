package Kamaitachi;
use 5.008001;
use Moose;

our $VERSION = '0.01';

use IO::Handle;
use IO::Socket::INET;
use Socket qw/IPPROTO_TCP TCP_NODELAY SOCK_STREAM/;
use Danga::Socket;
use Danga::Socket::Callback;
use Data::HexDump ();

use Kamaitachi::Socket;

with 'MooseX::LogDispatch';

has port => (
    is      => 'ro',
    isa     => 'Int',
    default => sub { 4423 },
);

sub BUILD {
    my $self = shift;

    my $ssock = IO::Socket::INET->new(
        LocalPort => $self->port,
        Type      => SOCK_STREAM,
        Blocking  => 0,
        ReuseAddr => 1,
        Listen    => 10,
    );
    IO::Handle::blocking($ssock, 0);

    Danga::Socket->AddOtherFds(
        fileno($ssock) => sub {
            my $csock = $ssock->accept or return;

            $self->logger->debug(sprintf("Listen child making a Client for %d.", fileno($csock)));

            IO::Handle::blocking($csock, 0);
            setsockopt($csock, IPPROTO_TCP, TCP_NODELAY, pack('l', 1)) or die;

            Kamaitachi::Socket->new(
                handle        => $csock,
                on_read_ready => sub { $self->event_read(@_) },
                context       => q{},
            );
        }
    );
}

sub run {
    Danga::Socket->EventLoop;
}

sub event_read {
    my ($self, $socket) = @_;

    my $bref = $socket->read(1024);
    return $socket->close unless defined $bref;

    # handshake
    if (not $socket->{handshaked}) {
        if (not $socket->{client_handshake_packet} and substr($$bref, 0, 1) eq pack('C', 0x03) ) {
            $self->logger->debug('start handshake');
            $socket->{client_handshake_packet} .= substr $$bref, 1;
        }
        else {
            $socket->{client_handshake_packet} .= $$bref;
        }

        if ( (my $len = length $socket->{client_handshake_packet} ) >= 1536) {
            $socket->push_back_read( substr $socket->{client_handshake_packet}, 1536 ) if $len > 1536;
            substr($socket->{client_handshake_packet}, 1536) = q[];

            $socket->{server_handshake_packet} .= pack('C', int rand 0xff) for 1 .. 1536;
            substr($socket->{server_handshake_packet}, 4, 4, pack('L', 0)); # XXX

            $socket->write(
                pack('C', 0x03) . $socket->{server_handshake_packet} . $socket->{client_handshake_packet}
            );

            $self->logger->debug('send handshake packet');
            $socket->{handshaked}++;
            $socket->{buffer} = q[];
        }
    }
    elsif ($socket->{handshaked} == 1) {
        $socket->{buffer} .= $$bref;
        if ( (my $len = length $socket->{buffer}) >= 1536) {
            $socket->push_back_read( substr $socket->{buffer}, 1536 ) if $len > 1536;
            substr( $socket->{buffer}, 1536 ) = q[];

            if ($socket->{buffer} eq $socket->{server_handshake_packet}) {
                $self->logger->debug('handshaked!');
                $socket->{buffer} = q[];
                $socket->{handshaked}++;
            }
            else {
                $self->logger->debug('handshake filed: invalid packet');
                $socket->close;
            }
        }
    }
    else {
        $self->dump( $$bref );
    }
}

sub dump {
    my $self = shift;
    $self->logger->debug("\n" . Data::HexDump::HexDump(shift) . "\n");
}

=head1 NAME

Kamaitachi - Module abstract (<= 44 characters) goes here

=head1 SYNOPSIS

  use Kamaitachi;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for this module was created by ExtUtils::ModuleMaker.
It looks like the author of the extension was negligent enough
to leave the stub unedited.

Blah blah blah.

=head1 AUTHOR

Daisuke Murase <typester@cpan.org>

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

1;
