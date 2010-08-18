package Kamaitachi::ConnectionHandler;
use Any::Moose;

use AnyEvent::Socket;
use Scalar::Util;

use MIME::Base64::URLSafe;
use Data::UUID;
use HTTP::Parser::XS qw(parse_http_request);
use HTTP::Response;

use Kamaitachi::Session;
use Kamaitachi::IO::RTMPT;

has host => (
    is      => 'rw',
    default => '0.0.0.0',
);

has port => (
    is      => 'rw',
    default => 1935,
);

has proto => (
    is      => 'rw',
    default => 'rtmp',
);

has ident => (
    is => 'rw',
);

has context => (
    is       => 'rw',
    weak_ref => 1,
);

has ug => (
    is         => 'rw',
    lazy_build => 1,
);

has connection_guard => (
    is => 'rw',
);

no Any::Moose;

sub BUILD {
    my ($self) = @_;

    my $guard = tcp_server $self->host, $self->port, sub {
        my ($fh) = @_
            or die "Accept failed: $!";
        return unless $self;

        my $context = $self->context;

        if ($self->proto =~ /t$/) {
            my $handle = AnyEvent::Handle->new( fh => $fh );
            $handle->on_eof(sub { });
            $handle->on_error(sub {
                $context->logger->error('connection error: ' . $_[2]);
                undef $handle;
            });

            $handle->on_read(sub {
                my ($handle) = @_;
                my $r = parse_http_request($handle->{rbuf}, \my %env);
                if (2 == $r) { # request is incomplete
                    return;
                }
                elsif (-1 == $r) { # request is broken
                    $context->logger->error('HTTP Request is broken');
                    $handle->push_shutdown;
                    return;
                }
                else {
                    my $data = substr $handle->{rbuf}, 0, $r, '';

                    my $len = $env{CONTENT_LENGTH};
                    unless ($len) {
                        $context->logger->error('CONTENT_LENGTH is not set');
                        $handle->push_shutdown;
                        return;
                    }

                    $handle->unshift_read( chunk => $len, sub {
                        my ($handle, $data) = @_;

                        my $res = HTTP::Response->new(200);
                        $res->header('Connection' => 'keep-alive');
                        $res->header('Content-Type' => 'application/x-fcs');

                        my $path_info = $env{PATH_INFO};

#                        use YAML;
#                        warn 'req';
#                        warn Dump \%env;

                        if ($path_info =~ m!^/fcs/ident!) {
                            $res->header('Content-Type' => 'text/plain');
                            $res->header('Content-Length' => length $self->ident);
                            $res->content($self->ident);
                        }
                        elsif ($path_info =~ m!^/open!) {
                            my $id = urlsafe_b64encode($self->ug->create);
                            $res->header('Cache-Control' => 'no-cache');
                            $res->header('Content-Length' => length($id) + 1);
                            $res->content("${id}\x0a");

                            my $io = Kamaitachi::IO::RTMPT->new(
                                fh     => $fh,
                                handle => $handle,
                            );
                            my $session = Kamaitachi::Session->new(
                                id      => $id,
                                fh      => $fh,
                                io      => $io,
                                proto   => $self->proto,
                                context => $context,
                            );
                            $context->add_session($session);
                        }
                        elsif ($path_info =~ m!^/(send|idle|close)/(.*?)/!) {
                            my ($cmd, $id) = ($1, $2);

                            my $session = $context->get_session($id);
                            unless ($session) {
                                $context->logger->error('invalid connection');
                                $handle->push_shutdown;
                                return;
                            }

                            if ($session->fh != $fh) {
                                my $io = Kamaitachi::IO::RTMPT->new(
                                    fh     => $fh,
                                    handle => $handle,
                                );
                                
                            }

                            die 'ok';
                        }
                        else {
                            $self->logger->error(sprintf 'Unknown command "%s"', $path_info);
                            $handle->push_shutdown;
                            return;
                        }

#                        warn 'res';
#                        warn 'HTTP/1.1 ' . $res->as_string;
                        $handle->push_write('HTTP/1.1 ' . $res->as_string);
                    });
                }
            });
        }
        else {
            my $id = urlsafe_b64encode($self->ug->create);

            my $session = Kamaitachi::Session->new(
                id      => $id,
                fh      => $fh,
                proto   => $self->proto,
                context => $context,
            );
            $context->add_session($session);
        }
    };
    Scalar::Util::weaken($self);
    $self->connection_guard($guard);
}

sub _build_ug {
    my ($self) = @_;
    Data::UUID->new;
}

__PACKAGE__->meta->make_immutable;

