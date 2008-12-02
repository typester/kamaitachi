package Service::LiveStreamingRecorder;
use Moose;
use MooseX::Types::Path::Class;

extends 'Kamaitachi::Service';

with 'Kamaitachi::Service::AutoConnect',
     'Kamaitachi::Service::Streaming',
     'Kamaitachi::Service::Recorder';

has record_output_dir => (
    is       => 'rw',
    isa      => 'Path::Class::Dir',
    required => 1,
    coerce   => 1,
);

sub record_output_dir { shift->{record_output_dir} }

sub on_invoke_record {
    my ($self, $session, $req) = @_;

    if (my $stream = $self->published($session)) {
        if ($req->args->[1] eq 'start') { # ustream like interface
            $self->record_start($session);
        }
        elsif ($req->args->[1] eq 'stop') {
            $self->record_stop($session);
        }
    }
}

sub published {
    my ($self, $session) = @_;
    my $stream = $self->stream_owner_session->[ $session->id ];
}

1;
