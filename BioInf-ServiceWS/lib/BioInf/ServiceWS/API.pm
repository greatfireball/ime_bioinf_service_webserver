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
    my $dat = decode_json($response->decoded_content());

    # go through projects and request all categories:
    foreach my $project (@{$dat->{_embedded}{elements}})
    {
	my $name = $project->{identifier};
	my $category_uri = $base_uri.$project->{_links}{categories}{href};

	my $request = GET $category_uri;
	$request->authorization_basic('apikey', $apikey);
	my $response = $ua->request($request);

	my $categories = decode_json($response->decoded_content());

	foreach my $cat (@{$categories->{_embedded}{elements}})
	{
	    next unless ($cat->{_type} eq "Category");
	    my $cat_link = $cat->{_links}{self}{href};
	    my $cat_title = $cat->{_links}{self}{title};

	    push(@{$data->{$name}}, { link => $cat_link, title => $cat_title });
	}
    }

    return $data;
};

1;
