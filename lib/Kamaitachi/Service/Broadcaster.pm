package Kamaitachi::Service::Broadcaster;
use Moose::Role;

with qw/Kamaitachi::Service::ChildHandler
        Kamaitachi::Service::AMFHandler
       /;

use Kamaitachi::Packet::Function;

sub broadcast {
    my ($self, $session, $packet) = @_;

    for my $child_session (@{ $self->child }) {
        next unless defined $child_session;
        next if $session->id eq $child_session->id;
        $child_session->io->write($packet);
    }
}

sub broadcast_stream {
    my ($self, $session, $packet) = @_;

    return unless $self->meta->does_role('Kamaitachi::Service::Streaming');

    my $stream_info = $self->get_stream_info($session) or return;

    for my $child_session_id (keys %{ $stream_info->{child} }  ) {
        my $child_session = $self->child->[ $child_session_id ];
        next unless defined $child_session;
        $child_session->io->write($packet);
    }
}

sub broadcast_stream_all {
    my ($self, $session, $packet) = @_;

    return unless $self->meta->does_role('Kamaitachi::Service::Streaming');

    my $stream_info = $self->get_stream_info($session) or return;

    for my $child_session_id ($stream_info->{owner}, keys %{ $stream_info->{child} }  ) {
        my $child_session = $self->child->[ $child_session_id ];
        next unless defined $child_session;
        $child_session->io->write($packet);
    }
}

sub broadcast_notify_packet {
    my ($self, $method, $data) = @_;

    my $notify_packet = Kamaitachi::Packet::Function->new(
        number => 3,
        type   => 0x14,
        id     => undef,
        method => $method,
        args   => [undef, $data],
    );
}

1;

__END__

=encoding utf8

=head1 NAME

Kamaitachi::Service::Broadcaster - service role to broadcast packet to others

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 broadcast

=head2 broadcast_notify_packet

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
