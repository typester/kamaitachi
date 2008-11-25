package Kamaitachi::Service::ConnectionHandler;
use Moose::Role;

sub connect_success_response {
    return(
        undef, {
            level       => 'status',
            code        => 'NetConnection.Connect.Success',
            description => 'Connection succeeded.',
        }
    );
}

sub connect_reject_response {
    my ($self, $reason) = @_;

    return(
        undef, {
            level       => 'status',
            code        => 'NetConnection.Connect.Rejected',
            description => $reason || '-',
        }
    );
}

1;

