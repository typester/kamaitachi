package Kamaitachi::Service::Broadcaster;
use Moose::Role;

with qw/Kamaitachi::Service::ChildHandler
        Kamaitachi::Service::AMFHandler
       /;

use Kamaitachi::Packet::Function;

sub broadcast {
    my ($self, $session, $packet) = @_;

    for my $child_session (@{ $self->child }) {
        next unless defined $child_session;
        next if $session->id eq $child_session->id;
        $child_session->io->write($packet);
    }
}

sub broadcast_notify_packet {
    my ($self, $method, $data) = @_;

    my $notify_packet = Kamaitachi::Packet::Function->new(
        number => 3,
        type   => 0x14,
        id     => undef,
        method => $method,
        args   => [undef, $data],
    );
}

1;
