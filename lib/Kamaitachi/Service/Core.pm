package Kamaitachi::Service::Core;
use Moose::Role;

use Kamaitachi::Packet;

with 'MooseX::LogDispatch';

has _read_bytes => (
    is      => 'rw',
    isa     => 'Int',
    default => sub { 0 },
);

# chunk size handler
before 'on_packet_chunk_size' => sub {
    my ($self, $session, $packet) = @_;
    $session->chunk_size( unpack('N', $packet->data) );
};

# auto response ping packet
before 'on_packet_ping' => sub {
    my ($self, $session, $ping) = @_;

    return unless $ping->size == 6;

    my $type = unpack('n', substr $ping->data, 0, 2);
    if ($type == 0x06) {
        my $pong = Kamaitachi::Packet->new(
            number => $ping->number,
            timer  => $ping->timer,
            type   => $ping->type,
            data   => pack('n', 0x07) . substr($ping->data, 2, 4),
        );
        $session->io->write($pong->serialize);
    }
};

# auto response bytes read packet
before "on_packet_$_" => sub {
    my ($self, $session, $packet) = @_;

    my $old = $self->_read_packet % (120 * 1024);
    $self->_read_packet( $self->_read_packet + $packet->size );
    my $new = $self->_read_packet % (120 * 1024);

    if ($old < $new) {
        my $bytes_read = Kamaitachi::Packet->new(
            number => 2,
            type   => 0x03,
            data   => pack('N', $self->_read_packet),
        );

        $session->io->write($bytes_read->serialize);
    }
} for qw/audio video/;

1;

