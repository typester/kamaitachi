package Kamaitachi::Service::Streaming;
use Moose::Role;

use Kamaitachi::Packet;

with 'Kamaitachi::Service::ChildHandler',
     'Kamaitachi::Service::NetStreamHandler';

has stream_chunk_size => (
    is      => 'rw',
    isa     => 'Int',
    default => sub { 0x1000 },
);

has stream_id => (
    is      => 'rw',
    isa     => 'Int',
    default => sub { 0 },
);

has stream_owner_session => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
);

has stream_child_session => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
);

has stream_info => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

before 'on_invoke_connect' => sub {
    my ($self, $session, $req) = @_;

    my $server_bw = Kamaitachi::Packet->new(
        number => 2,
        type   => 0x05,
        data   => pack('N', 2500000),
    );

    my $client_bw = Kamaitachi::Packet->new(
        number => 2,
        type   => 0x06,
        data   => pack('N', 2500000) . pack('C', 2),
    );

    my $unknown_ping = Kamaitachi::Packet->new(
        number => 2,
        type   => 0x04,
        data   => "\0" x 6,
    );

    $session->io->write( $server_bw );
    $session->io->write( $client_bw );
    $session->io->write( $unknown_ping );
};

sub on_invoke_createStream {
    my ($self, $session, $req) = @_;
    $req->response(undef, 1);
}

sub on_invoke_deleteStream {
    my ($self, $session, $req) = @_;
}

sub on_invoke_publish  {
    my ($self, $session, $req) = @_;

    my $name = $req->args->[1];
    $self->logger->debug(sprintf 'start publish "%s"', $name);

    if ($self->stream_info->{ $name }) {
        return $self->net_stream_status({
            level => 'error',
            code  => 'NetStream.Publish.BadName',
        });
    }

    $self->stream_owner_session->[ $session->id ] = $name;
    $self->stream_info->{ $name } = {
        owner => $session->id,
        child => {},
    };

    $self->net_stream_status('NetStream.Publish.Start');
}

sub on_invoke_play {
    my ($self, $session, $req) = @_;

    my $name = $req->args->[1];
    unless ($self->stream_info->{ $name }) {
        return $self->net_stream_status({
            level => 'error',
            code  => 'NetStream.Play.StreamNotFound',
        });
    }

    $self->stream_child_session->[ $session->id ] = $name;
    $self->stream_info->{ $name }{child}{ $session->id } = [0, 0];

    $session->io->write( $self->net_stream_status('NetStream.Play.Reset') );
    $session->io->write( $self->net_stream_status('NetStream.Play.Start') );

    return;
}

before on_packet_video => sub {
    my ($self, $session, $packet) = @_;

    my $stream = $self->stream_owner_session->[ $session->id ]
        or return; # XXX

    my $initial_frame;
    if (not $packet->partial) {
        # check key frame
        my $first = unpack('C', substr $packet->data, 0, 1);
        $initial_frame = $packet if ($first >> 4 == 1);
    }

    for my $child_id (keys %{ $self->stream_info->{$stream}{child} }) {
        my $child_session = $self->child->[$child_id] or next;

        unless ($self->stream_info->{$stream}{child}{$child_id}[0]) { # first
            next unless $initial_frame;
            $self->stream_info->{$stream}{child}{$child_id}[0]++;
            $child_session->io->write( $initial_frame->serialize($child_session->chunk_size) );
        }
        else {
            $child_session->io->write($packet->raw);
        }
    }
};

before on_packet_audio => sub {
    my ($self, $session, $packet) = @_;

    my $stream = $self->stream_owner_session->[ $session->id ]
        or return; # XXX

    for my $child_id (keys %{ $self->stream_info->{$stream}{child} }) {
        my $child_session = $self->child->[$child_id] or next;

        unless ($self->stream_info->{$stream}{child}{$child_id}[1]) { # first
            $self->stream_info->{$stream}{child}{$child_id}[1]++;
            $child_session->io->write( $packet->serialize($child_session->chunk_size) );
        }
        else {
            $child_session->io->write($packet->raw);
        }
    }
};

before 'on_close' => sub {
    my ($self, $session) = @_;

    my $owner_session_name = delete $self->stream_owner_session->[ $session->id ];
    my $child_session_name = delete $self->stream_child_session->[ $session->id ];

    if ($owner_session_name) {
        # TODO client notify.
        delete $self->stream_info->{ $owner_session_name };
    }
    elsif ($child_session_name) {
        delete $self->stream_info->{ $child_session_name }{child}{ $session->id };
    }
};

1;
