package Kamaitachi;
use 5.008001;
use Moose;

our $VERSION = '0.01';

use IO::Handle;
use IO::Socket::INET;
use Socket qw/IPPROTO_TCP TCP_NODELAY SOCK_STREAM/;
use Danga::Socket;
use Danga::Socket::Callback;

with 'MooseX::LogDispatch';

has port => (
    is      => 'rw',
    isa     => 'Int',
    default => sub { 4423 },
);

sub BUILD {
    my $self = shift;

    my $ssock = IO::Socket::INET->new(
        LocalPort => $self->port,
        Type      => SOCK_STREAM,
        Blocking  => 0,
        Reuse     => 1,
        Listen    => 10,
    );
    IO::Handle::blocking($ssock, 0);

    Danga::Socket->AddOtherFds(
        fileno($ssock) => sub {
            my $csock = $ssock->accept or return;

            $self->logger->debug(sprintf("Listen child making a Client for %d.", fileno($csock)));

            IO::Handle::blocking($csock, 0);
            setsockopt($csock, IPPROTO_TCP, TCP_NODELAY, pack('l', 1)) or die;

            Danga::Socket::Callback->new(
                handle        => $csock,
                on_read_ready => sub { $self->event_read(shift) },
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

    $socket->write($bref);
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
