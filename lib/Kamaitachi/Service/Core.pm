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
    warn 'Change chunk size to ' . unpack('N', $packet->data);
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
    elsif ($type == 0x03) {
        my $pong = Kamaitachi::Packet->new(
            number => $ping->number,
            timer  => $ping->timer,
            type   => $ping->type,
            data   => pack('n', 0) . substr($ping->data, 2, 4),
        );
        $session->io->write($pong);
    }
};

# auto response bytes read packet
before "on_packet_$_" => sub {
    my ($self, $session, $packet) = @_;

    my $old = int($self->_read_bytes / 125000);
    $self->_read_bytes( $self->_read_bytes + $packet->partial_data_length || $packet->size );
    my $new = int($self->_read_bytes / 125000);

    if ($old < $new) {
        my $bytes_read = Kamaitachi::Packet->new(
            number => 2,
            type   => 0x03,
            data   => pack('N', $self->_read_bytes % 2147483648), # steel from rtmpy.py
        );

        $session->io->write($bytes_read->serialize);
    }
} for qw/audio video/;

1;

__END__

=encoding utf8

=head1 NAME

Kamaitachi::Service::Core - core service role

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head1 SEE ALSO

L<Kamaitachi>,
L<Kamaitachi::Service>

=head1 AUTHOR

Daisuke Murase <typester@cpan.org>

Hideo Kimura <hide@cpan.org>

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
