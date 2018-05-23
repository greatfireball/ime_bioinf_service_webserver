package BioInf::ServiceWS::API;
use Dancer2;

use LWP::UserAgent;
use HTTP::Request::Common;

set serializer => 'JSON';

get '/openproject_categories' => sub {
    my $data = {};

    my $url    = '';
    my $apikey = '';

    my $u = URI->new($url);
    my $base_uri=$u->scheme."://".$u->host_port;

    # create the request to optain all accessable projects
    my $ua = LWP::UserAgent->new();
    my $request = GET $url.'/api/v3/projects';
    $request->authorization_basic('apikey', $apikey);
    my $response = $ua->request($request);
    $data = decode_json($response->decoded_content());

    return $data;
};

1;
