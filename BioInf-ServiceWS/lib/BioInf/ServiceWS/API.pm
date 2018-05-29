package BioInf::ServiceWS::API;
use Dancer2;

use LWP::UserAgent;
use HTTP::Request::Common;

set serializer => 'JSON';

my $url    = '';
my $apikey = '';
my $u = URI->new($url);
my $base_uri=$u->scheme."://".$u->host_port;

get '/openproject_get_topwps' => sub {
    my $output = {};

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
	$output->{$name} = { href => $project->{_links}{self}{href}, id => $project->{id}, wps => [] };
    }

    # get all working packages and assign them to the projects
    $request = GET $url.'/api/v3/work_packages';
    $request->authorization_basic('apikey', $apikey);
    $response = $ua->request($request);
    $dat = decode_json($response->decoded_content());

    # go through working packages and assign them
    foreach my $workingpackage (@{$dat->{_embedded}{elements}})
    {
	my $subject   = $workingpackage->{subject};
	my $id        = $workingpackage->{id};

	my $project   = $workingpackage->{_links}{project};
	my $ancestors = $workingpackage->{_links}{ancestors};
	my $children  = $workingpackage->{_links}{children};

	# skip, unless it has children
	next unless ($children && ref($children) eq "ARRAY" && @{$children}>0);
	# skip, unless the list of ancestors is empty
	next if ($ancestors && ref($ancestors) eq "ARRAY" && @{$ancestors}>0);

	push(@{$output->{$project->{title}}{wps}}, sprintf("%s(id:%d)", $subject, $id));
    }

    return $output;
};

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
	my $id = $project->{id};

	my $available_assignees_uri = $base_uri.'/av/api/v3/projects/'.$id.'/available_assignees';

	my $request = GET $available_assignees_uri;
	$request->authorization_basic('apikey', $apikey);
	my $response = $ua->request($request);

	my $available_assignees = decode_json($response->decoded_content());

	foreach my $assignee (@{$available_assignees->{_embedded}{elements}})
	{
	    next unless ($assignee->{_type} eq "User");
	    my $assignee_name = $assignee->{name};

	    push(@{$data->{$name}}, $assignee_name);
	}
    }

    # sort user names alphabetically
    foreach my $project (keys %{$data})
    {
	$data->{$project} = join(",", sort (@{$data->{$project}}));
    }
    return $data;
};

1;
