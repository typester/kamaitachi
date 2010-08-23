package Kamaitachi::Service::Core;
use Any::Moose '::Role';

use Kamaitachi::Packet::Control;

has window_size => (
    is      => 'rw',
    default => 2500000,
);

has client_window_size => (
    is      => 'rw',
    default => 2500000,
);

has _read_bytes => (
    is      => 'rw',
    default => 0,
);

has _sessions => (
    is      => 'rw',
    default => sub { {} },
);

after on_connect => sub {
    my ($self, $session, $req) = @_;

    $session->io->write(Kamaitachi::Packet::Control->window_size($self->window_size));
    $session->io->write(Kamaitachi::Packet::Control->peer_window_size($self->client_window_size));
    $session->io->write(Kamaitachi::Packet::Control->stream_begin);    
};

before on_packet_window_size => sub {
    my ($self, $session, $packet) = @_;

    my $size = unpack 'N', $packet->data;
    $self->client_window_size($size);
};

# auto response ping
before on_packet_control => sub {
    my ($self, $session, $ping) = @_;
    return unless $ping->is_full and $ping->size == 6;

    my $type = unpack 'n', substr($ping->data, 0, 2);
    if ($type == 0x06) {
        my $timer = substr($ping->data, 2, 4);
        $session->io->write(Kamaitachi::Packet::Control->pong($timer));
    }
};

# auto response bytes_read
before "on_packet_$_" => sub {
    my ($self, $session, $packet) = @_;
    return unless $packet->is_full;

    my $read = $self->{_read_bytes} += $packet->size;

    if ($read >= $self->client_window_size) {
        $session->io->write(Kamaitachi::Packet::Control->bytes_read($read));
        $self->{_read_bytes} = 0;
    }
} for qw/audio video/;

before on_connect => sub {
    my ($self, $session) = @_;
    $self->add_session($session);
};

after on_close => sub {
    my ($self, $session) = @_;
    $self->remove_session($session);
};

sub add_session {
    my ($self, $session) = @_;
    $self->_sessions->{ $session->id } = $session;
}

sub remove_session {
    my ($self, $session) = @_;
    delete $self->_sessions->{ $session->id };
}

sub get_session {
    my ($self, $session_id) = @_;
    $self->_sessions->{ $session_id };
}

sub get_all_sessions {
    my ($self) = @_;
    values %{ $self->_sessions };
}

1;

