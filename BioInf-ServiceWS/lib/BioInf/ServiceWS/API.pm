package BioInf::ServiceWS::API;
use Dancer2;

use LWP::UserAgent;
use HTTP::Request::Common;

set serializer => 'JSON';

my $url    = '';
my $apikey = '';
my $u = URI->new($url);
my $base_uri=$u->scheme."://".$u->host_port;

get '/openproject_categories' => sub {
    my $data = {};

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

	$data->{$name} = "";

	foreach my $cat (@{$categories->{_embedded}{elements}})
	{
	    next unless ($cat->{_type} eq "Category");
	    my $cat_link = $cat->{_links}{self}{href};
	    my $cat_title = $cat->{_links}{self}{title};

	    if ($data->{$name})
	    {
		$data->{$name} .= ','.$cat_title;
	    } else {
		$data->{$name} .= $cat_title;
	    }
	}
    }

    return $data;
};

get '/openproject_users' => sub {
    my $data = [];

    # create the request to optain all users
    foreach my $userid (1..100)
    {
	my $ua = LWP::UserAgent->new();
	my $request = GET $url.'/api/v3/users/'.$userid;
	$request->authorization_basic('apikey', $apikey);
	my $response = $ua->request($request);
	my $dat = decode_json($response->decoded_content());

	next unless ($dat->{status} eq "active" || $dat->{status} eq "invited");
	push(@{$data}, sprintf("%s (%s)", $dat->{name}, $dat->{status}));
    }

    return $data;
};

1;
