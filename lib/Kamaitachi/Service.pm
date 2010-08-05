package Kamaitachi::Service;
use Any::Moose;

with 'Kamaitachi::Service::Core';

no Any::Moose;

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

__PACKAGE__->meta->make_immutable;
