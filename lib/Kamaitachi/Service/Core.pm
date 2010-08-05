package Kamaitachi::Service::Core;
use Any::Moose '::Role';

use Kamaitachi::Packet;

has _read_bytes => (
    is      => 'rw',
    default => 0,
);

# auto response ping
before on_packet_ping => sub {
    my ($self, $session, $ping) = @_;
    return unless $ping->is_full and $ping->size == 6;

    my $type = unpack 'n', substr($ping->data, 0, 2);
    if ($type == 0x06) {
        my $pong = Kamaitachi::Packet->new(
            number => $ping->number,
            timer  => $ping->timer,
            type   => $ping->type,
            data   => pack('n', 0x07) . substr($ping->data, 2, 4),
        );
        $session->io->write($pong);
    }
    elsif ($type == 0x03) {
        my $pong = Kamaitachi::Packet->new(
            number => $ping->number,
            timer  => $ping->timer,
            type   => $type,
            data   => pack('n', 0) . substr($ping->data, 2, 4),
        );
        $session->io->write($pong);
    }
};

# auto response bytes_read
before "on_packet_$_" => sub {
    my ($self, $session, $packet) = @_;
    return unless $packet->is_full;

    my $old = int($self->_read_bytes / 125000);
    $self->_read_bytes( $self->_read_bytes + $packet->size );
    my $new = int($self->_read_bytes / 125000);

    if ($old < $new) {
        my $bytes_read = Kamaitachi::Packet->new(
            number => 2,
            type   => 0x03,
            data   => pack('N', $self->_read_bytes % 2147483648), # steel from rtmpy.py
        );

        $session->io->write($bytes_read);
    }
} for qw/audio video/;

1;

