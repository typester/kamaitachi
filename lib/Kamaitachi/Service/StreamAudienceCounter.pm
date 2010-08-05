package Kamaitachi::Service::StreamAudienceCounter;
use Any::Moose '::Role';

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

__END__

=encoding utf8

=head1 NAME

Kamaitachi::Service::StreamAudienceCounter - service role to count and broadcast streaming audience

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 get_stream_audience_count

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
