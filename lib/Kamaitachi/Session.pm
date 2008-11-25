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

has packet_handler => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub {[
        undef,                  # 0x00
        \&packet_chunksize,     # 0x01
        undef,                  # 0x02
        \&packet_bytes_read,    # 0x03
        \&packet_ping,          # 0x04
        \&packet_server_bw,     # 0x05
        \&packet_client_bw,     # 0x06
        undef,                  # 0x07
        \&packet_audio,         # 0x08
        \&packet_video,         # 0x09
        undef, undef, undef, undef, undef, # 0x0a - 0x0e
        \&packet_flex_stream,   # 0x0f
        \&packet_flex_shared_object, # 0x10
        \&packet_flex_message,       # 0x11
        \&packet_notify,             # 0x12
        \&packet_shared_object,      # 0x13
        \&packet_invoke,             # 0x14
        undef,                       # 0x15
        \&packet_flv_data,           # 0x16
    ]},
);

has packet_names => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub {[
        undef,
        'packet_chunksize',     # 0x01
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

has packets => (
    is      => 'rw',
    isa     => 'ArrayRef',
    lazy    => 1,
    default => sub { [] },
);

has chunk_size => (
    is      => 'rw',
    isa     => 'Int',
    lazy    => 1,
    default => sub { 128 },
);

has io => (
    is => 'rw',
    isa => 'Int',
);

no Moose;

sub handle_packet_connect {
    my ($self, $socket) = @_;

    my $io = $self->io;
    my $bref;

    $io->read(1) or return $io->reset;

    $bref = $io->read(0x600) or return $io->reset;
    my $client_handshake_packet = $$bref;

    $io->spin;

    $socket->write(
        pack('C', 0x03) . $self->handshake_packet . $client_handshake_packet
    );

    $self->handler( \&handle_packet_handshake );
}

sub handle_packet_handshake {
    my ($self, $socket) = @_;
    my $io = $self->io;

    my $bref = $io->read(0x600) or return $io->reset;

    $io->spin;

    my $packet = $$bref;

    if ($packet eq $self->handshake_packet) {
        $self->logger->debug(sprintf('handshake successful with client: %d', $self->id));
        $self->handler( \&handle_packet );
        $self->handler->($self, $socket);
    }
    else {
        $self->logger->debug(sprintf('handshake failed with client: %d', $self->id));
#        $socket->close;
        $self->handler( \&handle_packet ); # XXX: TODO
        $self->handler->($self, $socket);
    }
}

sub handle_packet {
    my ($self, $socket) = @_;

    while (my $packet = $self->io->get_packet( $self->chunk_size, $self->packets )) {
        $self->bytes_read( bytes::length($packet->raw) );
        next if $packet->type == 0x14 and $packet->size > bytes::length($packet->data);

        my $handler = $self->packet_handler->[ $packet->type ] || \&packet_unknown;
        my $name    = $self->packet_names->[ $packet->type ];

        if ($packet->type == 0x14 or !$name) { # invoke or unknown packet
            $handler->($self, $socket, $packet);
        }
        else {
            $self->dispatch( "on_$name", { packet => $packet } );
        }
    }
}

sub packet_unknown {
    my ($self, $socket, $packet) = @_;
    $self->logger->debug(sprintf('Unknown packet type: 0x%02x', $packet->type));
    $self->io->clear;
}

sub packet_chunksize {
    my ($self, $socket, $packet) = @_;
    $self->chunk_size( unpack('N', $packet->data) );
}

sub packet_bytes_read {
    my ($self, $socket, $packet) = @_;

    $self->logger->debug("bytes_read packet: not implement yet");

    use Data::HexDump;
    warn HexDump($packet->raw);

#    $socket->close;
}

sub packet_ping {
    my ($self, $socket, $packet) = @_;
    $self->logger->debug("bytes_read packet: not implement yet");
#    $socket->close;
}

sub packet_server_bw {
    my ($self, $socket, $packet) = @_;
    $self->logger->debug("server_bw packet: not implement yet");
#    $socket->close;
}

sub packet_client_bw {
    my ($self, $socket, $packet) = @_;
    $self->logger->debug("client_bw packet: not implement yet");
    $socket->close;
}

sub packet_audio {
    my ($self, $socket, $packet) = @_;

#    $self->logger->debug(sprintf('audio packet from %d', $self->id));

    for my $id (keys %{ $self->context->{child} || {} }) {
        my ($csession, $csocket) = @{ $self->context->{child}{$id} || [] };
        $csession->set_chunk_size($self->chunk_size) unless $self->chunk_size == $csession->chunk_size;
        $csession->broadcast( $csocket, $packet );
    }
}

sub packet_video {
    my ($self, $socket, $packet) = @_;

#    $self->logger->debug(sprintf('video packet from %d', $self->id));

    for my $id (keys %{ $self->context->{child} || {} }) {
        my ($csession, $csocket) = @{ $self->context->{child}{$id} || [] };
        $csession->set_chunk_size($self->chunk_size) unless $self->chunk_size == $csession->chunk_size;
        $csession->broadcast( $csocket, $packet );
    }
}

sub packet_flex_stream {
    my ($self, $socket, $packet) = @_;
    $self->logger->debug("flex stream packet: not implement yet");
    $socket->close;
}

sub packet_flex_shared_object {
    my ($self, $socket, $packet) = @_;
    $self->logger->debug("flex shared object packet: not implement yet");
    $socket->close;
}

sub packet_flex_message {
    my ($self, $socket, $packet) = @_;
    $self->logger->debug("flex message packet: not implement yet");
    $socket->close;
}

sub packet_notify {
    my ($self, $socket, $packet) = @_;
    $self->logger->debug("notify packet: not implement yet");
    $socket->close;
}

sub packet_shared_object {
    my ($self, $socket, $packet) = @_;
    $self->logger->debug("client_bw packet: not implement yet");
    $socket->close;
}

sub packet_invoke {
    my ($self, $socket, $packet) = @_;

    my $func = $packet->function;

    $self->logger->debug(sprintf('[invoke] -> %s', $func->method));

    if ($func->method eq 'connect') {
        my $connect_info = $func->args->[0];
        for my $service ( @{$self->context->services} ) {
            if ($connect_info->{app} =~ $service->[0]) {
                $self->service( $service->[1] );
                last;
            }
        }
    }

    my $res = $self->dispatch('on_method_' . $func->method, { packet => $packet, function => $func });
    if ($res) {
        $self->write( $socket, $res );
    }
}

sub packet_flv_data {
    my ($self, $socket, $packet) = @_;
    $self->logger->debug("flv info packet: not implement yet");
    $socket->close;
}

sub write {
    my ($self, $socket, $packet, $data) = @_;

#    if ($packet->isa('Kamaitachi::Packet::Function')) {
#        $self->packets->[ $packet->packet->number ] = $packet->packet;
#    }
#    else {
#        $self->packets->[ $packet->number ] = $packet;
#    }

    $socket->write( $data || $packet->serialize($self->chunk_size) );
}

sub broadcast {
    my ($self, $socket, $packet) = @_;

    if ($self->{received}{ $packet->number }) {
        $self->write($socket, $packet, $packet->raw);
    }
    else {
        if ($packet->type == 0x09) { # video
            return if $packet->partial;

            # wait for key frame
            my $first = unpack('C', substr $packet->data, 0, 1);
            return unless $first >> 4 == 1;

            $self->write( $socket, $packet );
        }
        elsif ($packet->type == 0x08) { # audio
            return unless $packet->size and bytes::length($packet->data);
            $self->write( $socket, $packet );
        }

        $self->{received}{ $packet->number }++;
    }
}

sub bytes_read {
    my ($self, $bytes) = @_;

    my $reported = $self->{bytes_reported} ||= 0;

    if ($reported + 1000 <= $bytes) {
        $self->io->write( pack('C*', 2,0,0,0,0,0,4,3) . pack('N', $bytes) );
        $self->{bytes_reported} = $bytes;
    }
}

sub set_chunk_size {
    my ($self, $chunk_size) = @_;

    my $set_chunk_size = Kamaitachi::Packet->new(
        number => 2,
        type   => 1,
        data   => pack('N', $chunk_size),
    );
    $self->io->write( $set_chunk_size->serialize );
    $self->chunk_size($chunk_size);
}

sub dispatch {
    my ($self, $name, @args) = @_;
    my $service = $self->service or return;

    if ($service->can($name)) {
        return $service->$name( $self, @args );
    }
    return;
}

sub close {
    my $self = shift;
    $self->logger->debug(sprintf("Closed client connection for %d.", $self->id));

    delete $self->context->sessions->[ $self->id ];
    delete $self->context->{child}{ $self->id };

    $self->dispatch( on_close => $self->id );
}

sub destroy {
}

__PACKAGE__->meta->make_immutable;
