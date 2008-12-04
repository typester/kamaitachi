package Service::LiveStreaming;
use Moose;

extends 'Kamaitachi::Service';

with 'Kamaitachi::Service::AutoConnect',
     'Kamaitachi::Service::Broadcaster',
     'Kamaitachi::Service::Streaming',
     'Kamaitachi::Service::StreamAudienceCounter';

sub broadcast_audience_count {
    my ($self, $session) = @_;

    my $count  = $self->get_stream_audience_count($session);
    my $packet = $self->broadcast_notify_packet( onMessage => "Audience: $count" );

    $self->broadcast_stream_all($session, $packet);
}

after 'on_invoke_play', 'on_invoke_closeStream'
    => \&broadcast_audience_count;

around on_close => sub {
    my ($next, $self, $session) = @_;

    $self->broadcast_audience_count($session);
    $next->($session);
};

1;

