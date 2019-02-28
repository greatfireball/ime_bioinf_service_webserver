package BioInf::ServiceWS::API;
use Dancer2;

use LWP::UserAgent;
use HTTP::Request::Common;
use Data::Dumper;

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

    unless ($response->is_success) {
	debug $response->status_line;
    }
    my $dat = decode_json($response->decoded_content());

    # go through projects and request all categories:
    foreach my $project (@{$dat->{_embedded}{elements}})
    {
	my $name = $project->{identifier};
	my $href = $project->{_links}{self}{href};
	my $id   = $project->{id};
	$output->{$href} = { name => $name, id => $id, wps => [] };
    }

    # get all working packages and assign them to the projects
    my $wp_counter = 1;
    while (1==1)
    {
	$request = GET $url.'/api/v3/work_packages?pageSize=1000&offset='.$wp_counter;
	$request->authorization_basic('apikey', $apikey);
	debug "GET request is ".$request->as_string();

	$response = $ua->request($request);

	unless ($response->is_success) {
	    debug $response->status_line;
	}
	$dat = decode_json($response->decoded_content());

	last unless (@{$dat->{_embedded}{elements}});

	# go through working packages and assign them
	foreach my $workingpackage (@{$dat->{_embedded}{elements}})
	{
	    my $subject   = $workingpackage->{subject};
	    my $id        = $workingpackage->{id};

	    my $project   = $workingpackage->{_links}{project};
	    my $ancestors = $workingpackage->{_links}{ancestors};
	    my $children  = $workingpackage->{_links}{children};

	    # skip, unless it has children
	    unless ($children && ref($children) eq "ARRAY" && @{$children}>0)
	    {
		debug "Skipping WP due to missing children: ".Dumper($workingpackage);
		next;
	    }
	    # skip, unless the list of ancestors is empty
	    if ($ancestors && ref($ancestors) eq "ARRAY" && @{$ancestors}>0)
	    {
		debug "Skipping WP due to existing ancestors: ".Dumper($workingpackage);
		next;
	    }

	    push(@{$output->{$project->{href}}{wps}}, sprintf("%s(id:%d)", $subject, $id));

	    # count the processed working package
	    $wp_counter++;
	}
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

get '/openproject_categories2' => sub {
    my ($_url, $_apikey) = ($u, $apikey);

    # create the request to optain all accessable projects
    my $ua = LWP::UserAgent->new();
    my $request = GET $_url.'/api/v3/projects';
    $request->authorization_basic('apikey', $_apikey);
    my $response = $ua->request($request);

    unless ($response->is_success) {
	debug $response->status_line;
    }
    my $dat = decode_json($response->decoded_content());

    my $projects = {};

    foreach my $element (@{$dat->{_embedded}{elements}})
    {
	my $project_id = $element->{id};
	if (! exists $projects->{$project_id})
	{
	    $projects->{$project_id}{ancestor} = {};
	    $projects->{$project_id}{children} = {};
	} else {
	    $projects->{$project_id}{ancestor} = {} unless (exists $projects->{$project_id}{ancestor});
	    $projects->{$project_id}{children} = {} unless (exists $projects->{$project_id}{children});
	}

	foreach my $source_key (qw(name createdAt updatedAt))
	{
	    $projects->{$project_id}{$source_key} = $element->{$source_key} unless (exists $projects->{$project_id}{$source_key});
	}

	my $children = &get_child_projects($project_id, $_url, $_apikey);

	foreach my $child_id (@{$children})
	{
	    $projects->{$project_id}{children}{$child_id}++;
	    $projects->{$child_id}{ancestor}{$project_id}++;
	}
    }

    # generate a level for each project
    my $min_level;
    foreach my $project (keys %{$projects})
    {
	$projects->{$project}{level} = int(keys %{$projects->{$project}{ancestor}});

	# check if the level is smaller than the levels before:
	if ((! defined $min_level) || $min_level>$projects->{$project}{level})
	{
	    $min_level = $projects->{$project}{level};
	}
    }

    print STDERR "Min_level: $min_level\n";
    # combine all top nodes into a super-node
    my @top_projects = sort {$projects->{$a}{name} cmp $projects->{$b}{name}} ( grep { $projects->{$_}{level} == $min_level } (keys %{$projects}) );

    my $top_node_id = 0;
    while (exists $projects->{$top_node_id})
    {
	$top_node_id--;
    }

    $projects->{$top_node_id}{level} = $min_level-1;

    foreach my $id (@top_projects)
    {
	$projects->{$top_node_id}{children}{$id}++;
	$projects->{$id}{ancestor}{$top_node_id}++;
    }

    my @output = ();

    &deepFirstSearch($projects, $top_node_id, \@output, $min_level);

    foreach my $curr (@output)
    {
	$curr->{name} = "="x($curr->{level}*3)."> ".$curr->{name};
    }

    return \@output;
};

sub deepFirstSearch
{
    my ($projects, $node, $output, $min_level) = @_;

    # get the level for the node
    my $current_level = $projects->{$node}{level};

    if ($current_level>=$min_level)
    {
	# save the current node in output
	push(@{$output}, {
	    id => $node,
	    name => $projects->{$node}{name},
	    level => $current_level
	     });
    }

    # get all children
    my @children = grep {
	exists $projects->{$_}{ancestor}{$node}
	&&
	$projects->{$_}{level}>$current_level
    } (keys %{$projects});

    return unless (@children);

    # sort the children by level and keep only the lowest
    @children = sort {$projects->{$a}{level} <=> $projects->{$b}{level}} (@children);
    my $req_level = $projects->{$children[0]}{level};
    @children = grep { $projects->{$_}{level} == $req_level } (@children);

    # sort by name
    @children = sort {$projects->{$a}{name} cmp $projects->{$b}{name}} (@children);
    # call DFS for each child
    foreach my $child (@children)
    {
	deepFirstSearch($projects, $child, $output, $min_level);
    }
}

sub get_child_projects
{
    my ($id, $_url, $_apikey) = @_;

    my $ua = LWP::UserAgent->new();
    my $request = GET $_url.'/api/v3/projects?filters=[{"ancestor":{"operator":"=","values":["'.$id.'"]}}]';
    $request->authorization_basic('apikey', $_apikey);
    my $response = $ua->request($request);

    unless ($response->is_success) {
	debug $response->status_line;
    }
    my $dat = decode_json($response->decoded_content());

    my @ids_4_children = map { $_->{id} } (@{$dat->{_embedded}{elements}});

    return (\@ids_4_children);
}

1;
