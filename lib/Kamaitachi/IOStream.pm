package Kamaitachi::IOStream;
use Moose;

use constant ENDIAN => unpack('S', pack('C2', 0, 1)) == 1 ? 'BIG' : 'LITTLE';

extends 'Data::AMF::IO';

use Kamaitachi::Packet;

has socket => (
    is       => 'rw',
    isa      => 'Object',
    weak_ref => 1,
    required => 1,
);

has buffer => (
    is      => 'rw',
    isa     => 'Str',
    default => sub { q[] },
    trigger => sub {
        my $self = shift;
        $self->buffer_length( bytes::length($self->buffer) );
    },
);

has buffer_length => (
    is      => 'rw',
    isa     => 'Int',
    default => sub { 0 },
);

has cursor => (
    is      => 'rw',
    isa     => 'Int',
    default => sub { 0 },
);

has chunk_size => (
    is      => 'rw',
    isa     => 'Int',
    default => sub { 128 },
);

has packets => (
    is      => 'rw',
    isa     => 'ArrayRef',
    lazy    => 1,
    default => sub { [] },
);

no Moose;

=head1 NAME

Kamaitachi::IOStream - RTMP stream reader/writer

=head1 DESCRIPTION

See L<Kamaitachi>.

=head1 METHODS

=head2 new

=head2 push

=cut

sub push {
    my ($self, $data) = @_;

    $self->buffer( $self->buffer . $data );
}

=head2 reset

=cut

sub reset {
    my $self = shift;

    $self->cursor(0);
    return;
}

=head2 spin

=cut

sub spin {
    my $self = shift;

    my $read        = substr $self->buffer, 0, $self->cursor;
    $self->{buffer} = substr $self->buffer, $self->cursor;
    $self->buffer_length( bytes::length($self->buffer) );
    $self->cursor(0);

    $read;
}

=head2 clear

=cut

sub clear {
    my $self = shift;
    $self->buffer(q[]);
    $self->buffer_length(0);
    $self->cursor(0);
}

=head2 read

=cut

sub read {
    my ($self, $len) = @_;

    return if $self->buffer_length < ($self->cursor + $len);

    my $data = substr $self->buffer, $self->cursor, $len;
    $self->{cursor} += $len;

    \$data;
}

=head2 read_u8

=cut

sub read_u8 {
    my $self = shift;

    my $bref = $self->read(1) or return;
    \unpack('C', $$bref);
}

=head2 read_u16

=cut

sub read_u16 {
    my $self = shift;

    my $data = $self->read(2) or return;
    \unpack('n', $$data);
}

=head2 read_s16

=cut

sub read_s16 {
    my $self = shift;

    my $data = $self->read(2) or return;

    return \unpack('s>', $$data) if $] >= 5.009002;
    return \unpack('s', $$data)  if ENDIAN eq 'BIG';
    return \unpack('s', swap($$data));
}

=head2 read_u24

=cut

sub read_u24 {
    my $self = shift;

    my $data = $self->read(3) or return;
    \unpack('N', "\0".$$data);
}

=head2 read_u32

=cut

sub read_u32 {
    my $self = shift;

    my $data = $self->read(4) or return;
    \unpack('N', $$data);
}

=head2 read_double

=cut

sub read_double {
    my $self = shift;

    my $data = $self->read(8) or return;

    return \unpack('d>', $$data) if $] >= 5.009002;
    return \unpack('d', $$data)  if ENDIAN eq 'BIG';
    return \unpack('d', swap($$data));
}

=head2 read_utf8

=cut

sub read_utf8 {
    my $self = shift;

    my $len = $self->read_u16 or return;
    my $bref = $self->read($len) or return;
}

=head2 read_utf8_long

=cut

sub read_utf8_long {
    my $self = shift;

    my $len = $self->read_u32 or return;
    my $bref = $self->read($len) or return;
}

=head2 write

=cut

sub write {
    my ($self, $data) = @_;

    if (ref $data) {
        confess qq{Can't write this object: "@{[ ref $data ]}"} unless $data->can('serialize');
        $data = $data->serialize($self->chunk_size);
    }

    $self->socket->write($data) if $self->socket;
}

=head2 get_packet

=cut

sub get_packet {
    my ($self) = @_;
    my $bref;

    my $chunk_size  = $self->chunk_size;
    my $packet_list = $self->packets;

    $bref = $self->read_u8 or return $self->reset;
    my $first = $$bref;

    my $header_size = $first >> 6;
    my $amf_number  = $first & 0x3f;

    if ($amf_number == 0) {
        $bref = $self->read_u8 or return $self->reset;
        $amf_number = $$bref;
    }
    elsif ($amf_number == 1) {
        $bref = $self->read_u16 or return $self->reset;
        $amf_number = $$bref;
    }

    my $packet = $packet_list->[ $amf_number ] || Kamaitachi::Packet->new( socket => $self->socket, number => $amf_number );

    if ($header_size <= 2) {
        if ($header_size == 2 and !$packet->size) { # XXX
            warn 'skip packet';
            $self->clear;
            return;
        }

        $bref = $self->read_u24 or return $self->reset;
        $packet->timer( $$bref );
        $packet->partial(1);
    }
    if ($header_size <= 1) {
        $bref = $self->read_u24 or return $self->reset;
        if ($$bref >= 100000) { # XXX: might be invalid packet...
            warn 'skip packet, invalid size:' . $$bref;
            $self->clear;
            return;
        }
        $packet->size( $$bref );

        $bref = $self->read_u8 or return $self->reset;
        $packet->type( $$bref );

        $packet->data(q[]);
        $packet->raw(q[]);
        $packet->partial(0);
    }
    if ($header_size <= 0) {
        $bref = $self->read_u32 or return $self->reset;
        $packet->obj( $$bref );
    }

    my $data = q[];
    my $size = $packet->size;

    if ($packet->data and bytes::length($packet->data) < $size) {
        $data = $packet->data;
        $size -= bytes::length($packet->data);
    }

    if ($size > 0) {
        my $want = $size <= $chunk_size ? $size : $chunk_size;

        $bref = $self->read($want) or return $self->reset;
        $packet->partial_data( $$bref );
        $data .= $packet->partial_data;
    }

    $packet->data($data);
    $packet->{raw} = $self->spin;

    $packet_list->[ $amf_number ] = $packet;

    $packet;
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
