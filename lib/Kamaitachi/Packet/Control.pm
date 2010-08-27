package Kamaitachi::Packet::Control;
use Any::Moose;

extends 'Kamaitachi::Packet';

has '+number' => (
    default => 2,
);

no Any::Moose;

sub chunk_size {
    my ($class, $size) = @_;

    $class->new(
        type => 1,
        data => pack('N', $size),
    );
}

sub bytes_read {
    my ($class, $size) = @_;

    $class->new(
        type => 3,
        data => pack('N', $size),
    );
}

sub window_size {
    my ($class, $size) = @_;

    $class->new(
        type => 5,
        data => pack('N', $size),
    );
}

sub peer_window_size {
    my ($class, $size, $limit) = @_;
    $limit = 2 unless defined $limit;

    $class->new(
        type => 6,
        data => pack('N', $size) . pack('C', $limit),
    );
}

sub stream_begin {
    my ($class, $stream_id) = @_;

    my $packet = $class->new( type => 4 );

    my $data = pack('n', 0) . pack('N', $stream_id || 0);
    $packet->data($data);

    $packet;
}

sub ping {
    my ($class, $timer) = @_;
    $timer = time unless defined $timer;

    my $packet = $class->new( type => 4 );

    my $data = pack('n', 6) . pack('N', $timer);
    $packet->data($data);

    $packet;
}

sub pong {
    my ($class, $timer) = @_;

    my $packet = $class->new( type => 4 );

    my $data = pack('n', 7) . pack('N', $timer);
    $packet->data($data);

    $packet;
}

__PACKAGE__->meta->make_immutable;
