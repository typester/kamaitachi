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

has packet_handler => (
    is => 'rw',
    isa => 'ArrayRef',
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
        \&packet_flv_info,           # 0x15
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

__PACKAGE__->meta->make_immutable;

sub handle_packet_connect {
    my ($self, $socket) = @_;
    my $bref;

    $socket->start_read;

    $socket->read_bytes(1) or return;

    $bref = $socket->read_bytes(0x600) or return;
    my $client_handshake_packet = $$bref;

    $socket->end_read;

    $socket->write(
        pack('C', 0x03) . $self->handshake_packet . $client_handshake_packet
    );

    $self->handler( \&handle_packet_handshake );
}

sub handle_packet_handshake {
    my ($self, $socket) = @_;

    $socket->start_read;
    my $bref = $socket->read_bytes(0x600) or return;
    $socket->end_read;

    my $packet = $$bref;

    if ($packet eq $self->handshake_packet) {
        $self->handler( \&handle_packet );
    }
    else {
        $self->logger->debug(sprintf('handshake failed with client: %d', $self->id));
        $self->handler( \&handle_packet ); # XXX: TODO
        #$socket->close;
    }
}

sub handle_packet {
    my ($self, $socket) = @_;

    my $packet = $socket->io->get_packet( $self->chunk_size, $self->packets ) or return;

    my $handler = $self->packet_handler->[ $packet->type ] || \&packet_unknown;
    $handler->($self, $socket, $packet);
}

sub packet_unknown {
    my ($self, $socket, $packet) = @_;
    $self->logger->debug(sprintf('Unknown packet type: 0x%02x', $packet->type));
    $socket->close;
}

sub packet_chunksize {
    my ($self, $socket, $packet) = @_;
    $self->logger->debug("chunksize packet: not implement yet");
    $socket->close;
}

sub packet_bytes_read {
    my ($self, $socket, $packet) = @_;
    $self->logger->debug("bytes_read packet: not implement yet");
    $socket->close;
}

sub packet_ping {
    my ($self, $socket, $packet) = @_;
    $self->logger->debug("ping packet: not implement yet");
#    $socket->close;
}

sub packet_server_bw {
    my ($self, $socket, $packet) = @_;
    $self->logger->debug("server_bw packet: not implement yet");
    $socket->close;
}

sub packet_client_bw {
    my ($self, $socket, $packet) = @_;
    $self->logger->debug("client_bw packet: not implement yet");
    $socket->close;
}

sub packet_audio {
    my ($self, $socket, $packet) = @_;

    $self->logger->debug(sprintf('audio packet from %d', $self->id));

    for my $id (keys %{ $self->context->{child} || {} }) {
        my ($csession, $csocket) = @{ $self->context->{child}{$id} || [] };

        if ($csession->{apublished}) {
            $csocket->write( $packet->raw );
        }
        else {
            $csocket->write( $packet->serialize );
            $csession->{apublished}++;
        }
    }
}

sub packet_video {
    my ($self, $socket, $packet) = @_;

    $self->logger->debug(sprintf('video packet from %d', $self->id));

    use YAML;
    use Data::HexDump;
    warn Dump({
        number => $packet->number,
        size   => $packet->size,
        type   => $packet->type,
    });
    warn HexDump($packet->raw);

    for my $id (keys %{ $self->context->{child} || {} }) {
        my ($csession, $csocket) = @{ $self->context->{child}{$id} || [] };

        if ($csession->{vpublished}) {
            $csocket->write( $packet->raw );
        }
        else {
            my $first = unpack('C', substr $packet->data, 0, 1);
            if ( $first >> 4 == 1 ) {
                $csocket->write( $packet->serialize );

                warn HexDump($packet->serialize);
                die;
                $csession->{vpublished}++;
            }
        }
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
        my $res = $func->response(undef, {
            level       => 'status',
            code        => 'NetConnection.Connect.Success',
            description => 'Connection succeeded.',
        });
        $socket->write( $res->serialize );
    }
    elsif ($func->method eq 'createStream') {
        my $res = $func->response(undef, 1);
        $socket->write( $res->serialize );
    }
    elsif ($func->method eq 'publish') {
        my $parser = $self->context->parser;
        my $onstatus = Kamaitachi::Packet->new(
            number => $func->packet->number + 1,
            type   => 0x14,
            obj    => 0x01000000,
            data   => $parser->serialize('onStatus', 1, undef, {
                level       => 'status',
                code        => 'NetStream.Publish.Start',
                description => '-',
            }),
        );
        $socket->write( $onstatus->serialize );
    }
    elsif ($func->method eq 'play') {
        warn 'play: ', $func->args->[1];
        my $parser = $self->context->parser;

#        my $onstatus = Kamaitachi::Packet->new(
#            number => $func->packet->number + 1,
#            type   => 0x14,
#            obj    => 0x01000000,
#            data   => $parser->serialize('onStatus', 1, undef, {
#                level       => 'status',
#                code        => 'NetStream.Play.Reset',
#                description => '-',
#            }),
#        );
#        $socket->write( $onstatus->serialize );

        my $onstatus2 = Kamaitachi::Packet->new(
            number => $func->packet->number + 1,
            type   => 0x14,
            obj    => 0x01000000,
            data   => $parser->serialize('onStatus', 1, undef, {
                level       => 'status',
                code        => 'NetStream.Play.Start',
                description => '-',
            }),
        );
        $socket->write( $onstatus2->serialize );

        $self->context->{child}{ $self->id } = [$self, $socket];
    }
}

sub packet_flv_info {
    my ($self, $socket, $packet) = @_;
    $self->logger->debug("flv info packet: not implement yet");
    $socket->close;
}

sub destroy {
    my $self = shift;
    $self->logger->debug(sprintf("Closed client connection for %d.", $self->id));
    delete $self->context->sessions->[ $self->id ];
    delete $self->context->{child}{ $self->id };
}

1;

