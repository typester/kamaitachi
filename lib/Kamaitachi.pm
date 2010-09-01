package Kamaitachi;
use Any::Moose;

our $VERSION = '0.05';

with 'Kamaitachi::Logger';

use AnyEvent;

use Data::AMF;
use Text::Glob qw/glob_to_regex/;

use Kamaitachi::ConnectionHandler;

has sessions => (
    is      => 'rw',
    default => sub { {} },
);

has services => (
    is      => 'rw',
    default => sub { [] },
);

has connection_handlers => (
    is      => 'rw',
    default => sub { [] },
);

has cv => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        AnyEvent->condvar;
    },
);

no Any::Moose;

sub add_handler {
    my ($self, %options) = @_;
    push @{ $self->connection_handlers },
        Kamaitachi::ConnectionHandler->new(%options, context => $self);
}

sub get_session {
    my ($self, $id) = @_;
    $self->sessions->{ $id };
}

sub add_session {
    my ($self, $session) = @_;
    $self->sessions->{ $session->id } = $session;
}

sub remove_session {
    my ($self, $session) = @_;
    delete $self->sessions->{ $session->id };
}

sub register_services {
    my ($self, @args) = @_;

    while (@args) {
        my $key   = shift @args;
        my $class = shift @args;

        unless (ref($class)) {
            eval qq{ use $class };
            die $@ if $@;

            $class = $class->new;
        }
        $class->context($self);

        push @{ $self->services }, [ glob_to_regex($key), $class ];
    }
}
    
sub run {
    my ($self) = @_;
    $self->cv->recv;
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

Kamaitachi - perl flash media server

=head1 SYNOPSIS

    use Kamaitachi;
    
    my $kamaitachi = Kamaitachi->new;
    $kamaitachi->add_handler( port => 1935 );
    
    $kamaitachi->register_services(
        'servive1' => 'Your::Service::Class1',
        'servive2' => 'Your::Service::Class2',
    );
    $kamaitachi->run;

=head1 DESCRIPTION

Kamaitachi is perl implementation of Adobe's RTMP(Real Time Messaging Protocol).

Now kamaitachi supports Remoting and MediaStreaming via RTMP. SharedObject is not implemented yet.

This 0.x is development *alpha* version. API Interface and design are stil fluid.

If you want to use kamaitachi, look at example directory. it contains both server script and client swf.

=head1 DEVELOPMENT

GitHub: http://github.com/typester/kamaitachi

IRC: #kamaitachi @ chat.freenode.net

=head1 METHODS

=head2 new

    Kamaitachi->new( %options );

Create kamaitachi server object.

=head2 register_services

    $kamaitachi->register_services(
        'rpc/echo'    => 'Service::Echo',
        'rpc/chat'    => 'Service::Chat',
        'stream/live' => 'Service::LiveStreaming',
        'stream/rec'  => Service::LiveStreamingRecorder->new( record_output_dir => $dir ),
    );

Register own service classes.

=head2 run

    $kamaitachi->run

Start kamaitachi

=head1 AUTHOR

Daisuke Murase <typester@cpan.org>

Hideo Kimura <hide@cpan.org>

=head1 COPYRIGHT AND LICENSE

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
