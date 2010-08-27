package Kamaitachi::Session;
use Any::Moose;

use AnyEvent::Handle;
use Scalar::Util ();
use Try::Tiny;

use Kamaitachi::Packet;
use Kamaitachi::Packet::Function;

has [qw/id fh proto/] => (
    is       => 'ro',
    required => 1,
);

has fileno => (
    is      => 'rw',
    lazy    => 1,
    default => sub { fileno($_[0]->{fh}) },
);

has context => (
    is       => 'rw',
    weak_ref => 1,
    handles  => ['logger'],
);

has io => (
    is         => 'rw',
    lazy_build => 1,
);

has service => (
    is => 'rw',
);

has packet_names => (
    is      => 'rw',
    default => sub {[
        undef,
        'packet_chunk_size',    # 0x01
        undef,                  # 0x02
        'packet_bytes_read',    # 0x03
        'packet_control',       # 0x04
        'packet_window_size',   # 0x05
        'packet_peer_window_size',         # 0x06
        undef,                             # 0x07
        'packet_audio',                    # 0x08
        'packet_video',                    # 0x09
        undef, undef, undef, undef, undef, # 0x0a - 0x0e
        'packet_notify3',                  # 0x0f      data AMF3
        'packet_shared_object3',           # 0x10
        'packet_invoke3',                  # 0x11 invoke AMF3
        'packet_notify',                   # 0x12 data AMF0
        'packet_shared_object',            # 0x13
        'packet_invoke',                   # 0x14 invoke AMF0
        undef,                             # 0x15
        'packet_flv_data',                 # 0x16
    ]},
);

has streams => (
    is      => 'rw',
    default => sub { [] },
);

no Any::Moose;

sub BUILD {
    my ($self) = @_;

    $self->io->on_error(sub {
        my ($h, $fatal, $message) = @_;

        if ($self) {
            $self->logger->error(sprintf '[%d] Connection error: %s', $self->fileno, $message);
            $self->close;
        }
        $h->destroy;
    });

    $self->io->on_eof(sub {
        if ($self) {
            if ($self->proto =~ /t$/) {
                # keep session at HTTP tunneling protocol.
                # TODO: timeout for clearing session
            }
            else {
                $self->close;
            }
        }
    });

    my $packet_handler = sub { $self->packet_handler(@_) };
    $self->io->handle_client_handshaking(
        on_complete => sub {
            my ($h) = @_;
            $self->context->logger->debug(sprintf '[%d] handshake successful', $self->fileno);
            $self->io->handle_rtmp_packet(
                on_packet => $packet_handler,
            );            
        },
        on_fail => sub {
            my ($h, $reason) = @_;
            $self->context->logger->debug(sprintf '[%d] handshake failed: %s', $self->fileno, $reason);
            $self->close;
        },
    );
    Scalar::Util::weaken($self);

    $self->logger->debug(sprintf '[%d] Established connection (id:%s)', $self->fileno, $self->id);
}

sub DEMOLISH {
    my ($self) = @_;
    $self->logger->debug(sprintf '[%d] Closing connection', $self->fileno);
}

sub packet_handler {
    my ($self, $packet) = @_;

    my $name = $self->packet_names->[ $packet->type ];
    unless (defined $name) {
        $self->logger->debug(sprintf '[%d] unknown packet: 0x%02x', $self->fileno, $packet->type);
        return;
    }
    #$self->logger->debug(sprintf '[%d] got packet: 0x%02x (%s)', $self->fileno, $packet->type, $name);

    # all packet handler
    $self->dispatch(on_packet => $packet);

    # type packet handler
    if ($packet->type == 0x14) {
        $self->packet_invoke($packet) if $packet->is_full;
    }
    else {
        $self->dispatch("on_$name", $packet );
    }
}

sub packet_invoke {
    my ($self, $packet) = @_;

    my ($method, $id, @args, $err);
    try {
        ($method, $id, @args) = $self->io->decode_amf($packet->data);
    } catch {
        $err = $_;
    };

    if ($err) {
        $self->logger->debug(sprintf '[%d] Decording AMF data failed: %s', $self->fileno, $err);
        $self->close;
        return;
    }
        
    my $f = Kamaitachi::Packet::Function->new(
        %$packet,
        method => $method,
        id     => $id,
        args   => \@args,
    );
    $self->logger->debug(sprintf '[%d] [invoke] -> %s csid:%d', $self->fileno, $f->method, $f->number)
        unless $f->method eq 'vol';

    if ($f->method eq 'connect') {
        my $connect_info = $f->args->[0];
        for my $service (@{ $self->context->services }) {
            if ($connect_info->{app} =~ $service->[0]) {
                $self->service($service->[1]);
                $self->dispatch( on_connect => $packet );
                last;
            }
        }

        unless (defined $self->service) {
            my $res = $f->result(undef, {
                level       => 'error',
                code        => 'NetConnection.Connect.InvalidApp',
                description => '-',
            });
            $self->io->write($res);
            return;
        }
    }

    my $res = $self->dispatch('on_invoke_' . $f->method, $f );
    if (defined $res && Scalar::Util::blessed($res) && $res->isa('Kamaitachi::Packet')) {
        $self->io->write($res);
    }
}

sub dispatch {
    my ($self, $name, @args) = @_;

    my $service = $self->service or return;

    if (my $code = $service->can($name)) {
        return $code->( $service, $self, @args );
    }
    return;
}

sub set_chunk_size {
    my ($self, $size) = @_;

    my $packet = Kamaitachi::Packet->new(
        number => 2,
        type   => 1,
        data   => pack('N', $size),
    );
    $self->io->write($packet);
    $self->io->write_chunk_size($size);
}

sub close {
    my ($self) = @_;

    $self->service->on_close($self) if $self->service;
    $self->context->remove_session($self);
}

sub _build_io {
    my ($self) = @_;

    my $io_class = 'Kamaitachi::IO::' . uc $self->proto;
    Any::Moose::load_class($io_class);

    $io_class->new( fh => $self->fh );
}

__PACKAGE__->meta->make_immutable;


