package Kamaitachi::Session;
use Moose;

use Kamaitachi::IOStream;

with 'MooseX::LogDispatch';

has id => (
    is       => 'ro',
    isa      => 'Int',
    required => 1,
);

has context => (
    is       => 'rw',
    isa      => 'Object',
    required => 1,
    weak_ref => 1,
);

has handler => (
    is      => 'rw',
    isa     => 'CodeRef',
    default => sub { \&handle_packet_connect },
);

has service => (
    is  => 'rw',
    isa => 'Object',
);

has packet_names => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub {[
        undef,
        'packet_chunk_size',    # 0x01
        undef,                  # 0x02
        'packet_bytes_read',    # 0x03
        'packet_ping',          # 0x04
        'packet_server_bw',     # 0x05
        'packet_client_bw',     # 0x06
        undef,                  # 0x07
        'packet_audio',         # 0x08
        'packet_video',         # 0x09
        undef, undef, undef, undef, undef, # 0x0a - 0x0e
        'packet_flex_stream',   # 0x0f
        'packet_flex_shared_object', # 0x10
        'packet_flex_message',       # 0x11
        'packet_notify',             # 0x12
        'packet_shared_object',      # 0x13
        'packet_invoke',             # 0x14
        undef,                       # 0x15
        'packet_flv_data',           # 0x16
    ]},
);

has handshake_packet => (
    is      => 'rw',
    isa     => 'Str',
    default => sub {
        my $packet = q[];
        $packet .= pack('C', int rand 0xff) for 1 .. 0x600;
        substr $packet, 4, 4, pack('L', 0);
        $packet;
    },
);

has io => (
    is      => 'rw',
    isa     => 'Kamaitachi::IOStream',
    handles => ['chunk_size', 'packets'],
);

no Moose;

=head1 NAME

Kamaitachi::Session - Kamaitachi connection handler

=head1 DESCRIPTION

See L<Kamaitachi>.

=head1 METHODS

=head2 new

=head2 handle_packet_connect

=cut

sub handle_packet_connect {
    my ($self) = @_;

    my $io = $self->io;
    my $bref;

    $io->read(1) or return $io->reset;

    $bref = $io->read(0x600) or return $io->reset;
    my $client_handshake_packet = $$bref;

    $io->spin;

    $io->write(
        pack('C', 0x03) . $self->handshake_packet . $client_handshake_packet
    );

    $self->handler( \&handle_packet_handshake );
}

=head2 handle_packet_handshake

=cut

sub handle_packet_handshake {
    my ($self) = @_;
    my $io = $self->io;

    my $bref = $io->read(0x600) or return $io->reset;

    $io->spin;

    my $packet = $$bref;

    if ($packet eq $self->handshake_packet) {
        $self->logger->debug(sprintf('handshake successful with client: %d', $self->id));
        $self->handler( \&handle_packet );
        $self->handler->($self);
    }
    else {
        $self->logger->debug(sprintf('handshake failed with client: %d', $self->id));
#        $socket->close;
        $self->handler( \&handle_packet ); # TODO: correct handshake impl!
        $self->handler->($self);
    }
}

=head2 handle_packet

=cut

sub handle_packet {
    my ($self) = @_;

    while (my $packet = $self->io->get_packet) {
        next if $packet->type == 0x14 and $packet->size > bytes::length($packet->data);

        my $name = $self->packet_names->[ $packet->type ] || 'unknown';

        if ($name eq 'packet_invoke') {
            $self->packet_invoke($packet);
        }
        else {
            $self->dispatch( "on_$name", $packet );
        }
    }
}

=head2 packet_invoke

=cut

sub packet_invoke {
    my ($self, $packet) = @_;

    my $func_packet = $packet->function or return;

    $self->logger->debug(sprintf('[invoke] -> %s', $func_packet->method));

    if ($func_packet->method eq 'connect') {
        my $connect_info = $func_packet->args->[0];
        for my $service ( @{$self->context->services} ) {
            if ($connect_info->{app} =~ $service->[0]) {
                $self->service( $service->[1] );
                $self->dispatch( on_connect => $packet );
                last;
            }
        }

        unless ($self->service) {
            my $res = $func_packet->response(undef, {
                level       => 'error',
                code        => 'NetConnection.Connect.InvalidApp',
                description => '-',
            });
            $self->io->write( $res );
            return;
        }
    }

    my $res = $self->dispatch('on_invoke_' . $func_packet->method, $func_packet );
    if (defined $res and (ref($res) || '') =~ /^Kamaitachi::Packet/) {
        $self->io->write( $res );
    }
}

=head2 dispatch

=cut

sub dispatch {
    my ($self, $name, @args) = @_;
    my $service = $self->service or return;

    if ($service->can($name)) {
        return $service->$name( $self, @args );
    }
    return;
}

=head2 set_chunk_size

=cut

sub set_chunk_size {
    my ($self, $size) = @_;

    my $packet = Kamaitachi::Packet->new(
        number => 2,
        type   => 0x1,
        data   => pack('N', $size),
    );
    $self->io->write($packet);
    $self->chunk_size( $size );
}

=head2 close

=cut

sub close {
    my $self = shift;
    $self->logger->debug(sprintf("Closed client connection for %d.", $self->id));

    delete $self->context->sessions->[ $self->id ];

    $self->dispatch( on_close => $self );
}

=head1 AUTHOR

Daisuke Murase <typester@cpan.org>

Hideo Kimura <hide@cpan.org>

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

__PACKAGE__->meta->make_immutable;
