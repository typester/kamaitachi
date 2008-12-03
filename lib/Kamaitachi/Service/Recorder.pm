package Kamaitachi::Service::Recorder;
use Moose::Role;

use Path::Class qw/file dir/;
use Data::AMF::IO;

requires 'record_output_dir';

has recorder_handles => (
    is      => 'rw',
    isa     => 'ArrayRef',
    lazy    => 1,
    default => sub { [] },
);

has recorder_time => (
    is      => 'rw',
    isa     => 'ArrayRef',
    lazy    => 1,
    default => sub { [] },
);

sub record_start {
    my ($self, $session, $name, $mode, $flags) = @_;

    my $dir  = dir($self->record_output_dir);
    my $file = $dir->file($name . '.flv');

    my $fh = $file->open($mode ||= 'w', $flags) or die $!;

    # write flv header
    print $fh 'FLV';
    print $fh pack('C', 1);
    print $fh pack('C', 0b00000101); # XXX: this is video&audio bitmask, TODO: treat this correctly
    print $fh pack('N', 9);
    print $fh pack('N', 0);

    $self->recorder_handles->[ $session->id ] = $fh;
    $self->recorder_time->[ $session->id ] = [ 0, 0 ];
}

sub record_stop {
    my ($self, $session) = @_;

    my $fh = delete $self->recorder_handles->[ $session->id ];
    $fh->close if $fh;

    delete $self->recorder_time->[ $session->id ];
}

after "on_packet_$_" => sub {
    my ($self, $session, $packet) = @_;
    return unless $self->is_owner($session);
    return unless $packet->size == bytes::length($packet->data);

    my $fh = $self->recorder_handles->[ $session->id ] or return;

    if ($packet->type eq 0x09) {
        my $initial_frame;
        if (not $packet->partial) {
            # check key frame
            my $first = unpack('C', substr $packet->data, 0, 1);
            $initial_frame = $packet if ($first >> 4 == 1);
        }

        if ($self->recorder_time->[ $session->id ][0] == 0) {
            return unless $initial_frame;
        }
    }
    else {
        return unless $self->recorder_time->[ $session->id ][0];
    }

    my $io = Data::AMF::IO->new;
    $io->write_u8( $packet->type );
    $io->write_u24( $packet->size );

    my $t = $self->recorder_time->[ $session->id ][ $packet->type == 0x09 ? 0 : 1 ] += $packet->timer;
    $io->write_u24($t);
    $io->write_u8( $t >> 24 );

    $io->write_u24(0);
    $io->write( $packet->data );

    $io->write_u32( $packet->size + 11 );

    print $fh $io->data;
} for qw/audio video/;

after on_close => sub {
    my ($self, $session) = @_;
    $self->record_stop($session);
};

1;

__END__

=encoding utf8

=head1 NAME

Kamaitachi::Service::Recorder - service role to record flv

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 record_start

=head2 record_stop

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
