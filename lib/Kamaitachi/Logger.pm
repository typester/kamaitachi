package Kamaitachi::Logger;
use Any::Moose '::Role';
use Any::Moose '::Util::TypeConstraints';

use Log::Handler;

subtype 'LogHandler' => as 'Object' => where { $_->isa('Log::Handler') };
coerce 'LogHandler'
    => from 'Str' => via {
        my $h = Log::Handler->new;
        $h->config( config => $_ );
        $h;
    }
    => from 'HashRef' => via {
        my $h = Log::Handler->new;
        $h->config( config => $_ );
        $h;
    };

has log_level => (
    is      => 'rw',
    default => 'debug',
);

has logger => (
    isa        => 'LogHandler',
    is         => 'rw',
    lazy_build => 1,
);

no Any::Moose;

sub _build_logger {
    my $self = shift;

    my $h = Log::Handler->new;
    $h->config( config => {
        screen => {
            log_to   => 'STDERR',
            maxlevel => $self->log_level,
            minlevel => 'emerg',
        },
    });
    $h;
}

1;

__END__

=head1 NAME


