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

has io => (
    is => 'rw',
    isa => 'Int',
);

__PACKAGE__->meta->make_immutable;

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

    # server bandwidth
    my $server_bw = Kamaitachi::Packet->new(
        number => 2,
        type   => 5,
        data   => pack('C*', 0, 0x26, 0x25, 0xa0),
    );
    $self->write($socket, $server_bw);

    # client bandwidth
    my $client_bw = Kamaitachi::Packet->new(
        number => 2,
        type   => 6,
        data   => pack('C*', 0, 0x26, 0x25, 0xa0, 0x02),
    );
    $self->write($socket, $client_bw);
}

sub handle_packet {
    my ($self, $socket) = @_;

    while (my $packet = $self->io->get_packet( $self->chunk_size, $self->packets )) {
        next if $packet->type == 0x14 and $packet->size > bytes::length($packet->data);

        my $handler = $self->packet_handler->[ $packet->type ] || \&packet_unknown;
        $handler->($self, $socket, $packet);
    }
}

sub packet_unknown {
    my ($self, $socket, $packet) = @_;
    $self->logger->debug(sprintf('Unknown packet type: 0x%02x', $packet->type));
    $self->io->clear;
}

sub packet_chunksize {
    my ($self, $socket, $packet) = @_;
    $self->logger->debug("chunksize packet: not implement yet");
    use Data::HexDump;
    warn 'chunk';
    warn HexDump($packet->raw);
    $socket->close;
}

sub packet_bytes_read {
    my ($self, $socket, $packet) = @_;
    $self->logger->debug("bytes_read packet: not implement yet");
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
        $csession->broadcast( $csocket, $packet );
    }
}

sub packet_video {
    my ($self, $socket, $packet) = @_;

#    $self->logger->debug(sprintf('video packet from %d', $self->id));

    for my $id (keys %{ $self->context->{child} || {} }) {
        my ($csession, $csocket) = @{ $self->context->{child}{$id} || [] };
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
#        $socket->write( pack('C*', 2,0,0,0,0,0,4,5,0,0,0,0,0,0x26,0x25,0xa0) );
#        $socket->write( pack('C*', 2,0,0,0,0,0,5,4,0,0,0,0,0,0x26,0x25,0xa0,0x02) );
#        $socket->write( pack('C*', 2,0,0,0,0,0,4,5,0,0,0,0,0,2,0,0) );

        my $res = $func->response(undef, {
            level       => 'status',
            code        => 'NetConnection.Connect.Success',
            description => 'Connection succeeded.',
        });
        $self->write( $socket, $res );
    }
    elsif ($func->method eq 'createStream') {
        my $res = $func->response(undef, 1);
        $self->write( $socket, $res );
    }
    elsif ($func->method eq 'publish') {
        my $parser = $self->context->parser;

        # set chunk_size
#        my $setchunk = Kamaitachi::Packet->new(
#            number => 2,
#            timer  => 0,
#            type   => 1,
#            data   => pack('N', 4096),
#            obj    => 0,
#        );
#        $self->write( $socket, $setchunk );
#        $self->chunk_size(4096);

        my $onstatus = Kamaitachi::Packet->new(
            number => 4,
            type   => 0x14,
            obj    => 0x01000000,
            data   => $parser->serialize('onStatus', 1, undef, {
                level       => 'status',
                code        => 'NetStream.Publish.Start',
                description => '-',
                clientid    => 1,
            }),
        );
        $self->write($socket, $onstatus);
    }
    elsif ($func->method eq 'play') {
        warn 'play: ', $func->args->[1];
        my $parser = $self->context->parser;

#        my $set_chunk_size = Kamaitachi::Packet->new(
#            number => 2,
#            type   => 1,
#            data   => pack('N', 4096),
#        );
#        $self->write($socket, $set_chunk_size);
#        $self->chunk_size(4096);

        # aaa bbb
        my $aaa = Kamaitachi::Packet->new(
            number => 2,
            type   => 4,
            data   => pack('C*', 0, 4, 0, 0, 0, 1),
        );
        my $bbb = Kamaitachi::Packet->new(
            number => 2,
            type   => 4,
            data   => pack('C*', 0, 0, 0, 0, 0, 1),
        );

#        $self->write($socket, $aaa);
#        $self->write($socket, $bbb);

        my $onstatus = Kamaitachi::Packet->new(
            number => 6,
            type   => 0x14,
            obj    => $packet->obj,
            data   => $parser->serialize('onStatus', 1, undef, {
                level       => 'status',
                code        => 'NetStream.Play.Reset',
                description => '-',
                clientid    => 1,
            }),
        );
        $self->write($socket, $onstatus);

        my $onstatus2 = Kamaitachi::Packet->new(
            number => 6,
            type   => 0x14,
            obj    => $packet->obj,
            data   => $parser->serialize('onStatus', 1, undef, {
                level       => 'status',
                code        => 'NetStream.Play.Start',
                description => '-',
                clientid    => 1,
            }),
        );
        $self->write($socket, $onstatus2);


        #        $self->context->{child}{ $self->id } = [$self, $socket];
        open my $fh, '<', '/home/typester/dev/tmp/smile.mp3';

        use MPEG::Audio::Frame;

        my $stream;
        $stream = sub {
            my ($seconds, $bytes) = (0, 0);

            while (my $frame = MPEG::Audio::Frame->read($fh)) {
                my $audio = Kamaitachi::Packet->new(
                    number => 4,
                    type   => 0x08,
                    obj    => $packet->obj,
                    data   => pack('C', 0x2f) . $frame->asbin,
                );
                $seconds += $frame->seconds;
                $bytes   += $frame->length;

                $self->write($socket, $audio);

                last if 0.1 <= $seconds;
            }

            Danga::Socket->AddTimer($seconds, $stream);
        };
        Danga::Socket->AddTimer(1, $stream);
    }
}

sub packet_flv_info {
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

sub destroy {
    my $self = shift;
    $self->logger->debug(sprintf("Closed client connection for %d.", $self->id));
    delete $self->context->sessions->[ $self->id ];
    delete $self->context->{child}{ $self->id };
}

1;

