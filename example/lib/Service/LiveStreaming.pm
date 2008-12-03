package Service::LiveStreaming;
use Moose;

extends 'Kamaitachi::Service';

with 'Kamaitachi::Service::AutoConnect',
     'Kamaitachi::Service::Broadcaster',
     'Kamaitachi::Service::Streaming';

sub broadcast_audience_count {
    my ($self, $session, $req) = @_;
    
    my $stream_info = $self->get_stream_info($session) or return;
    my $count = scalar keys %{$stream_info->{child}};
    my $res = $self->broadcast_notify_packet( onMessage => "Audience: $count" );
    $session->io->write($res);
    $self->broadcast( $session => $res );
    return $req->response;      # return null response
}

after on_invoke_play => sub  {
    my ($self, $session, $req) = @_;
    
    $self->broadcast_audience_count($session, $req);    
};

after on_invoke_closeStream => sub  {
    my ($self, $session, $req) = @_;
    
    $self->broadcast_audience_count($session, $req);    
};

after on_close => sub  {
    my ($self, $session, $req) = @_;
    
    $self->broadcast_audience_count($session, $req);    
};

1;
