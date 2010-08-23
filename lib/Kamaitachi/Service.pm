package Kamaitachi::Service;
use Any::Moose;

with 'Kamaitachi::Service::Core';

no Any::Moose;

sub on_connect { 0 }
sub on_close { 0 }

sub on_packet_chunk_size { }
sub on_packet_bytes_read { }
sub on_packet_control { }
sub on_packet_window_size { }
sub on_packet_peer_window_size { }
sub on_packet_audio { }
sub on_packet_video { }
sub on_packet_notify3 { }
sub on_packet_shared_object3 { }
sub on_packet_invoke3 { }
sub on_packet_notify { }
sub on_packet_shared_object { }
sub on_packet_invoke { }
sub on_packet_flv_data { }

__PACKAGE__->meta->make_immutable;
