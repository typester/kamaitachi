package Kamaitachi::Packet;
use Moose;

use Kamaitachi::Packet::Function;

has timer => (
    is  => 'rw',
    isa => 'Int',
);

has size => (
    is  => 'rw',
    isa => 'Int',
);

has type => (
    is  => 'rw',
    isa => 'Int',
);

has obj => (
    is => 'rw',
);

has data => (
    is  => 'rw',
    isa => 'Str',
);

has socket => (
    is       => 'rw',
    isa      => 'Object',
    weak_ref => 1,
);

__PACKAGE__->meta->make_immutable;

sub read {
    my ($class, $socket) = @_;

    my $first = unpack('C', $socket->read_bytes(1) || return);

    my $header_size = $first >> 6;
    my $amf_number  = $first & 0x3f;

    if ($amf_number == 0) {
        $amf_number = unpack('C', $socket->read_bytes(1));
    }
    elsif ($amf_number == 1) {
        $amf_number = unpack('n', $socket->read_bytes(2));
    }

    my $packet = $socket->session->packets->[ $amf_number ] ||= $class->new( socket => $socket );

    my $read_24bit_int = sub {
        my @data = unpack('C*', $socket->read_bytes(3));
        $data[0] << 16 ^ $data[1] << 8 ^ $data[2];
    };

    if ($header_size <= 2) {
        $packet->{timer} = $read_24bit_int->();
    }
    if ($header_size <= 1) {
        $packet->{size} = $read_24bit_int->();
        $packet->{type} = unpack('C', $socket->read_bytes(1));
    }
    if ($header_size <= 0) {
        $packet->{obj} = unpack('N', $socket->read_bytes(4));
    }

    my $data       = q[];
    my $size       = $packet->{size};
    my $chunk_size = $socket->session->chunk_size;

    if ($size <= $chunk_size) {
        $data = $socket->read_bytes($size);
    }
    else {
        my $read = $chunk_size;
        $data .= $socket->read_bytes($chunk_size);

        while ($read < $size) {
            $socket->read_bytes(1);

            my $rest  = $size - $read;
            my $bytes = $rest > $chunk_size ? $chunk_size : $rest;

            $data .= $socket->read_bytes($bytes) or die;
            $read += $bytes;
        }
    }
    $packet->{data} = $data;

    $packet;
}

sub serialize {
    my $self = shift;

    
}

sub function {
    my $self = shift;

    my ($method, $id, $args) = $self->socket->session->amf->deserialize($self->data);
    Kamaitachi::Packet::Function->new(
        method => $method,
        id     => $id,
        args   => $args,
        packet => $self,
    );
}

1;

