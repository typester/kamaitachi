package Service::LiveStreaming;
use Moose;

extends 'Kamaitachi::Service';

with 'Kamaitachi::Service::AutoConnect',
     'Kamaitachi::Service::Broadcaster',
     'Kamaitachi::Service::Streaming',
     'Kamaitachi::Service::StreamAudienceCounter';
1;
