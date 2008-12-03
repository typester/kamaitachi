package Kamaitachi::Service;
use Moose;

with 'Kamaitachi::Service::Core';

no Moose;

=head1 NAME

Kamaitachi::Service - Kamaitachi service base class

=head1 DESCRIPTION

See L<Kamaitachi>.

=head1 METHODS

=head2 on_connect

=head2 on_close

=head2 on_packet_chunk_size

=head2 on_packet_bytes_read

=head2 on_packet_ping

=head2 on_packet_server_bw

=head2 on_packet_client_bw

=head2 on_packet_audio

=head2 on_packet_video

=head2 on_packet_flex_stream

=head2 on_packet_flex_shared_object

=head2 on_packet_flex_message

=head2 on_packet_packet_notify

=head2 on_packet_shared_object

=head2 on_packet_invoke

=head2 on_packet_flv_data

=head2 on_packet_unknown

=cut

# service hooks
sub on_connect { 0 }
sub on_close { 0 }

sub on_packet_chunk_size { }
sub on_packet_bytes_read { }
sub on_packet_ping { }
sub on_packet_server_bw { }
sub on_packet_client_bw { }
sub on_packet_audio { }
sub on_packet_video { }
sub on_packet_flex_stream { }
sub on_packet_flex_shared_object { }
sub on_packet_flex_message { }
sub on_packet_packet_notify { }
sub on_packet_shared_object { }
sub on_packet_invoke { }
sub on_packet_flv_data { }
sub on_packet_unknown { }



__PACKAGE__->meta->make_immutable;
