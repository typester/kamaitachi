package Kamaitachi;
use 5.008001;
use Moose;

our $VERSION = '0.01';

use IO::Handle;
use IO::Socket::INET;
use Socket qw/IPPROTO_TCP TCP_NODELAY SOCK_STREAM/;
use Danga::Socket;
use Danga::Socket::Callback;
use Data::AMF;
use Text::Glob qw/glob_to_regex/;

use Kamaitachi::Socket;
use Kamaitachi::Session;

with 'MooseX::LogDispatch';

has port => (
    is      => 'rw',
    isa     => 'Int',
    default => sub { 1935 },
);

has sessions => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
);

has parser => (
    is      => 'rw',
    isa     => 'Object',
    lazy    => 1,
    default => sub {
        Data::AMF->new( version => 0 ),
    },
);

has buffer_size => (
    is      => 'rw',
    isa     => 'Int',
    default => sub { 8192 },
);

has services => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
);

no Moose;

=head1 NAME

Kamaitachi - perl flash media server

=head1 SYNOPSIS

use Kamaitachi;

    my $kamaitachi = Kamaitachi->new( port => 1935 );
    
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

Issues: http://karas.unknownplace.org/ditz/kamaitachi/

IRC: #kamaitachi @ chat.freenode.net

=head1 METHODS

=head2 new

    Kamaitachi->new( %options );

Create kamaitachi server object.

Available option parameters are:

=over 4

=item port

port number to listen (default 1935)

=item buffer_size

socket buffer size to read (default 8192)

=back

=cut

sub BUILD {
    my $self = shift;

    my $ssock = IO::Socket::INET->new(
        LocalPort => $self->port,
        Type      => SOCK_STREAM,
        Blocking  => 0,
        ReuseAddr => 1,
        Listen    => 10,
    ) or die $!;
    IO::Handle::blocking($ssock, 0);

    Danga::Socket->AddOtherFds(
        fileno($ssock) => sub {
            my $csock = $ssock->accept or return;

            $self->logger->debug(sprintf("Listen child making a Client for %d.", fileno($csock)));

            IO::Handle::blocking($csock, 0);
            setsockopt($csock, IPPROTO_TCP, TCP_NODELAY, pack('l', 1)) or die;

            my $session = Kamaitachi::Session->new(
                id      => fileno($csock),
                context => $self,
            );
            $self->sessions->[ $session->id ] = $session;

            Kamaitachi::Socket->new(
                handle        => $csock,
                context       => $self,
                session       => $session,
                on_read_ready => sub {
                    my $socket = shift;

                    my $bref = $socket->read( $self->buffer_size );
                    unless (defined $bref) {
                        $socket->close;
                        return;
                    }

                    $session->io->push($$bref);
                    $session->handler->( $session );
                },
            );
        }
    );
}

=head2 register_services

    $kamaitachi->register_services(
        'rpc/echo'    => 'Service::Echo',
        'rpc/chat'    => 'Service::Chat',
        'stream/live' => 'Service::LiveStreaming',
        'stream/rec'  => Service::LiveStreamingRecorder->new( record_output_dir => $dir ),
    );

Register own service classes.

=cut

sub register_services {
    my ($self, @args) = @_;

    local $Text::Glob::strict_wildcard_slash = 0;

    while (@args) {
        my $key   = shift @args;
        my $class = shift @args;

        unless (ref($class)) {
            eval qq{ use $class };
            die $@ if $@;

            $class = $class->new;
        }

        push @{ $self->services }, [ glob_to_regex($key), $class ];
    }
}

=head2 run

    $kamaitachi->run

Start kamaitachi

=cut

sub run {
    my $self = shift;

    Danga::Socket->AddTimer(
        0,
        sub {
            my $poll
                = $Danga::Socket::HaveKQueue ? 'kqueue'
                : $Danga::Socket::HaveEpoll  ? 'epoll'
                :                              'poll';
            $self->logger->debug(
                "started kamaitachi port $self->{port} with $poll"
            );
        }
    );

    Danga::Socket->EventLoop;
}

=head1 AUTHOR

Daisuke Murase <typester@cpan.org>

Hideo Kimura <hide@cpan.org>

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut

__PACKAGE__->meta->make_immutable;
