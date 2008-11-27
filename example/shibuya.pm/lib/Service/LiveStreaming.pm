package Service::LiveStreaming;
use Moose;

extends 'Kamaitachi::Service';

with 'Kamaitachi::Service::AutoConnect',
     'Kamaitachi::Service::Streaming';

1;
