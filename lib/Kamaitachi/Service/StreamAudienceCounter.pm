package Kamaitachi::Service::StreamAudienceCounter;
use Moose::Role;

has stream_audience_count => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} },
);

sub get_stream_audience_count {
    my ($self, $session) = @_;

    my $stream = $self->get_stream_name($session) or return;
    return $self->stream_audience_count->{$stream} || 0;
}

after on_invoke_play => sub  {
    my ($self, $session, $req) = @_;

    my $stream = $self->get_stream_name($session) or return;
    my $stream_info = $self->get_stream_info($stream) or return;
    $self->{stream_audience_count}{$stream} = keys %{ $stream_info->{child} };
};

after on_invoke_closeStream => sub  {
    my ($self, $session, $req) = @_;

    my $stream = $self->get_stream_name($session) or return;
    $self->{stream_audience_count}{$stream}--;
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
};


1;

