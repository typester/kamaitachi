package Kamaitachi::Service::StreamAudienceCounter;
use Moose::Role;

has stream_audience_count => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

sub broadcast_audience_count {
    my ($self, $session) = @_;

    my $stream = $self->get_stream_name($session) or return;
    my $count  = $self->stream_audience_count->{$stream} || 0;
    my $invoke = $self->broadcast_notify_packet( onMessage => "Audience: $count" );

    $self->broadcast_stream_all( $session => $invoke );
}

after on_invoke_play => sub  {
    my ($self, $session, $req) = @_;

    my $stream = $self->get_stream_name($session) or return;

    $self->{stream_audience_count}{$stream}++;
    $self->broadcast_audience_count($session);
};

after on_invoke_closeStream => sub  {
    my ($self, $session, $req) = @_;

    my $stream = $self->get_stream_name($session) or return;

    $self->{stream_audience_count}{$stream}--;
    $self->broadcast_audience_count($session);
};

before on_close => sub  {
    my ($self, $session) = @_;

    my $stream = $self->get_stream_name($session) or return;

    if ($self->is_owner($session)) {
        delete $self->{stream_audience_count}{$stream};
    }
    else {
        $self->{stream_audience_count}{$stream}--;
    }

    $self->broadcast_audience_count($session);
};


1;

