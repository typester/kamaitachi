package Kamaitachi::Packet::Function;
use Moose;

use Data::AMF;

extends 'Kamaitachi::Packet';

has method => (
    is       => 'rw',
    isa      => 'Str',
);

has id => (
    is       => 'rw',
    isa      => 'Maybe[Int]',
);

has args => (
    is      => 'rw',
    isa     => 'ArrayRef',
    lazy    => 1,
    default => sub { [] },
);

has parser => (
    is      => 'rw',
    isa     => 'Object',
    lazy    => 1,
    default => sub {
        Data::AMF->new;
    }
);

no Moose;

=head1 NAME

Kamaitachi::Packet::Function - RTMP function packet

=head1 DESCRIPTION

See L<Kamaitachi>.

=head1 METHODS

=head2 new

=head2 new_from_packet

=cut

sub new_from_packet {
    my $class = shift;
    my $args  = @_ > 1 ? {@_} : $_[0];

    my $packet = $args->{packet}
        or confess 'require packet';

    my $self = $class->new(
        %$packet,
        %$args,
    );

    my ($method, $id, @args);
    eval {
        ($method, $id, @args) = $self->parser->deserialize($packet->data);
    };
    if ($@) {
        return;
    }

    $self->{method} = $method;
    $self->{id}     = $id;
    $self->{args}   = \@args;

    $self;
}

=head2 response

=cut

sub response {
    my ($self, @obj) = @_;

    Kamaitachi::Packet::Function->new(
        %$self,
        method => '_result',
        args   => \@obj,
    );
}

=head2 error

=cut

sub error {
    my ($self, @obj) = @_;

    Kamaitachi::Packet::Function->new(
        %$self,
        method => '_error',
        args   => \@obj,
    );
}

=head2 serialize

=cut

sub serialize {
    my $self = shift;

    my $data = $self->parser->serialize(
        $self->method,
        $self->id,
        @{ $self->args },
    );

    my $packet = Kamaitachi::Packet->new(
        %$self,
        size => bytes::length($data),
        data => $data,
    );

    $packet->serialize(@_);
};

=head1 AUTHOR

Daisuke Murase <typester@cpan.org>

Hideo Kimura <hide@cpan.org>

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

1;
