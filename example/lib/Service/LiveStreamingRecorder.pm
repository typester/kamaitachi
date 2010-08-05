package Service::LiveStreamingRecorder;
use Any::Moose;
use Any::Moose 'X::Types::Path::Class';

extends 'Kamaitachi::Service';

with 'Kamaitachi::Service::AutoConnect',
     'Kamaitachi::Service::Streaming',
     'Kamaitachi::Service::Recorder';

has output_dir => (
    is       => 'rw',
    isa      => 'Path::Class::Dir',
    required => 1,
    coerce   => 1,
);

no Any::Moose;

sub record_output_dir { shift->output_dir }

sub on_invoke_record {
    my ($self, $session, $req) = @_;

    if (my $stream = $self->published($session)) {
        if ($req->args->[1] eq 'start') { # ustream like interface
            $self->record_start($session, $stream . '.' . time);
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

__PACKAGE__->meta->make_immutable;

