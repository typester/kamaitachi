package Kamaitachi::Service::Streaming;
use Moose::Role;

use Kamaitachi::Packet;

with 'Kamaitachi::Service::ChildHandler',
    'Kamaitachi::Service::NetStreamHandler';

has stream_chunk_size => (
    is      => 'rw',
    isa     => 'Int',
    default => sub {0x1000},
);

has stream_id => (
    is      => 'rw',
    isa     => 'Int',
    default => sub {0},
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
    my ( $self, $session, $req ) = @_;

    $self->send_server_bw($session);
    $self->send_client_bw($session);
    $self->send_clear($session);
};

sub on_invoke_createStream {
    my ( $self, $session, $req ) = @_;
    $req->response( undef, 1 );
}

sub on_invoke_deleteStream {
    my ( $self, $session, $req ) = @_;

}

sub on_invoke_closeStream {
    my ( $self, $session, $req ) = @_;

    my $stream_info = $self->get_stream_info($session) or return;

    if ( $self->is_owner($session) ) {
        $self->send_status( $session, 'NetStream.Unpublish.Success' );
        for my $child_id ( keys %{ $stream_info->{child} } ) {
            my $child_session = $self->child->[$child_id] or next;
            $self->send_status( $child_session, 'NetStream.Unpublish.Notify' );
        }
    }
    else {
        delete $stream_info->{child}{ $session->id };
    }

}

sub on_invoke_releaseStream {
    my ( $self, $session, $req ) = @_;

    #XXX: called from FME
}

sub on_invoke_publish {
    my ( $self, $session, $req ) = @_;

    my $name = $req->args->[1];
    $self->logger->debug( sprintf 'start publish "%s"', $name );

    if ( $self->stream_info->{$name} ) {
        if ( $self->is_owner($session) ) {
            my $stream_info = $self->get_stream_info($session) or return;
            for my $child_id ( keys %{ $stream_info->{child} } ) {
                my $child_session = $self->child->[$child_id] or next;
                $self->send_status( $child_session,
                    'NetStream.Publish.Notify' );
            }
        }
        else {
            return $self->send_status(
                $session,
                {   level => 'error',
                    code  => 'NetStream.Publish.BadName',
                }
            );
        }
    }
    else {

        $self->stream_owner_session->[ $session->id ] = $name;
        $self->stream_info->{$name} = {
            owner => $session->id,
            child => {},
        };
    }
    $self->send_status( $session, 'NetStream.Publish.Start' );
}

sub on_invoke_play {
    my ( $self, $session, $req ) = @_;

    my $name = $req->args->[1];
    unless ( $self->stream_info->{$name} ) {
        return $self->send_status(
            $session,
            {   level => 'error',
                code  => 'NetStream.Play.StreamNotFound',
            }
        );
    }

    $self->stream_child_session->[ $session->id ] = $name;
    $self->stream_info->{$name}{child}{ $session->id } = [ 0, 0 ];

    my $owner_session = $self->child->[ $self->stream_info->{$name}{owner} ]
        or return $self->send_status(
        $session,
        {   level => 'error',
            code  => 'NetStream.Play.StreamNotFound',
        }
        );

    unless ( $owner_session->chunk_size == $session->chunk_size ) {
        $session->set_chunk_size( $owner_session->chunk_size );
    }

    $self->send_clear($session);
    $self->send_status( $session, 'NetStream.Play.Reset' );
    $self->send_status( $session, 'NetStream.Play.Start' );
}

sub on_invoke_pause {
    my ( $self, $session, $req ) = @_;

    my $is_pause = $req->args->[1];
    my $position = $req->args->[2];    # ignore when live streaming

    my $stream_info = $self->get_stream_info($session) or return;

    if ($is_pause) {
        delete $stream_info->{child}{ $session->id };
        $self->send_status( $session, 'NetStream.Pause.Notify' );
    }
    else {
        $self->send_status( $session, 'NetStream.Unpause.Notify' );

        $stream_info->{child}{ $session->id } = [ 0, 0 ];

        # reset chunk_size
        my $owner = $self->child->[ $stream_info->{owner} ];
        if ( $owner and $owner->chunk_size != $session->chunk_size ) {
            $session->set_chunk_size( $owner->chunk_size );
        }
    }
}

sub on_invoke_seek {
    my ( $self, $session, $req ) = @_;

    my $position = $req->args->[1];

    #TODO: send NetStream.Seek.Notify
}

before on_packet_video => sub {
    my ( $self, $session, $packet ) = @_;

    my $stream_info = $self->get_stream_info($session) or return;

    my $initial_frame;
    if ( not $packet->partial ) {

        # check key frame
        my $first = unpack( 'C', substr $packet->data, 0, 1 );
        $initial_frame = $packet if ( $first >> 4 == 1 );
    }

    for my $child_id ( keys %{ $stream_info->{child} } ) {
        my $child_session = $self->child->[$child_id] or next;

        unless ( $stream_info->{child}{$child_id}[0] ) {    # first
            next unless $initial_frame;
            $stream_info->{child}{$child_id}[0]++;
            $child_session->io->write(
                $initial_frame->serialize( $child_session->chunk_size ) );
        }
        else {
            $child_session->io->write( $packet->raw );
        }
    }
};

before on_packet_audio => sub {
    my ( $self, $session, $packet ) = @_;

    my $stream_info = $self->get_stream_info($session) or return;

    for my $child_id ( keys %{ $stream_info->{child} } ) {
        my $child_session = $self->child->[$child_id] or next;

        unless ( $stream_info->{child}{$child_id}[1] ) {    # first
            $stream_info->{child}{$child_id}[1]++;
            $child_session->io->write(
                $packet->serialize( $child_session->chunk_size ) );
        }
        else {
            $child_session->io->write( $packet->raw );
        }
    }
};

before 'on_close' => sub {
    my ( $self, $session ) = @_;

    my $owner_session_name
        = delete $self->stream_owner_session->[ $session->id ];
    my $child_session_name
        = delete $self->stream_child_session->[ $session->id ];

    if ($owner_session_name) {

        # TODO client notify.
        delete $self->stream_info->{$owner_session_name};
    }
    elsif ($child_session_name) {
        delete $self->stream_info->{$child_session_name}{child}
            { $session->id };
    }
};

sub get_stream_name {
    my ( $self, $session ) = @_;
    my $stream = $self->stream_owner_session->[ $session->id ]
        || $self->stream_child_session->[ $session->id ];
}

sub get_stream_info {
    my ( $self, $session_or_name ) = @_;
    $session_or_name = $self->get_stream_name($session_or_name)
        if ref $session_or_name;

    my $stream_info = $self->stream_info->{$session_or_name} or return;
}

sub is_owner {
    my ( $self, $session ) = @_;
    my $info = $self->get_stream_info($session) or return;
    $info->{owner} == $session->id;
}

1;

__END__

=encoding utf8

=head1 NAME

Kamaitachi::Service::Streaming - service role to handle media streaming

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 on_invoke_createStream

=head2 on_invoke_deleteStream

=head2 on_invoke_closeStream

=head2 on_invoke_releaseStream

=head2 on_invoke_publish

=head2 on_invoke_play

=head2 on_invoke_pause

=head2 on_invoke_seek

=head2 get_stream_name

=head2 get_stream_info

=head2 is_owner

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
