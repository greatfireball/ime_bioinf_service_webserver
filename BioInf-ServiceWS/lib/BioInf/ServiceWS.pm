package BioInf::ServiceWS;
use Dancer2;
use Digest::SHA qw(hmac_sha256_hex);
use Digest::MD5;
use File::Basename;

use LWP::UserAgent;
use HTTP::Request::Common;
use DateTime;
use DateTime::TimeZone;

our $VERSION = '0.2.1';

get '/create_wp' => sub {
    template 'create_wp';
};

get '/create_wp2' => sub {
    template 'create_wp2';
};

post '/create_wp2', sub {
    redirect '/create_wp';
};

post '/create_wp' => sub {
    my $dat = request->params;

    my $package_tree_name = $dat->{wpname};
    my $username = $dat->{assignee};
    $username =~ s/\s+\([^)]+\)$//;

    my $apikey = "";
    my $uri    = "";

    # get the project
    my $project = find_project($uri, $apikey, $dat->{project});

    # get the category
    my $category = find_category($uri, $apikey, $dat->{category}, $project);

    # get the user
    my $user = find_user($uri, $apikey, $username);

    my $now = DateTime->now( time_zone => DateTime::TimeZone->new(name=> 'local'));
    $now->set_time_zone('UTC');
    my $date = $now->ymd('-');

    my $u = URI->new($uri);
    my $base_uri=$u->scheme."://".$u->host_port;

    my $settings = {};
    if ($user)
    {
	$settings->{assignee} = { href => $user };
    }
    if ($category)
    {
	$settings->{category} = { href => $category };
    }
    if ($date)
    {
	$settings->{startDate} = $date;
    }
    my $top_wp = add_subtree($base_uri, $project, $package_tree_name, $apikey, $settings);

    my $href = $base_uri.$top_wp->{_links}{self}{href};
    # delete api/v3 from $href
    $href =~ s/api\/v3//;
    template 'created_wp' => { 'title' => 'Created a working package', 'href' => $href, 'name' => $package_tree_name };

};

sub create_wp_4_project
{
    my ($url, $project, $subject, $apikey, $settings) = @_;

    my %setting = (%{$settings});
    $setting{subject} = $subject;

    my $notify = "?notify=true";
    if (exists $setting{notify} && $setting{notify} == 0)
    {
	$notify = "?notify=false";
	delete $setting{notify};
    }

    my $ua = LWP::UserAgent->new();
    my $u = URI->new($url);
    my $base_uri=$u->scheme."://".$u->host_port;

    my $uri = $base_uri.$project->{_links}{createWorkPackageImmediate}{href}.$notify;

    my $request = POST $uri;

    $request->authorization_basic('apikey', $apikey);

    $request->header("Content-Type" => "application/json");
    $request->content(to_json(\%setting));
    $request->header("Content-Length" => length($request->content));

    # print Debug info URI
    debug "POST request is ".$request->as_string();
    my $response = $ua->request($request);

    my $dat = decode_json($response->decoded_content());

    return $dat;
}

sub get_wp_from_uri
{
    my ($uri, $apikey) = @_;

    my $ua = LWP::UserAgent->new();

    my $request = GET $uri;
    $request->authorization_basic('apikey', $apikey);

    my $response = $ua->request($request);

    my $dat = decode_json($response->decoded_content());

    return $dat;
}

sub add_subtree
{
    my ($base_uri, $project, $top_name, $apikey, $settings) = @_;

    my $top_wp = create_wp_4_project($base_uri, $project, $top_name, $apikey, $settings);
    my $top_uri = $base_uri.$top_wp->{_links}{self}{href};

    my $wp = get_wp_from_uri($top_uri, $apikey);

    $settings->{notify} = 0;
    my $structure = [
	{ name => "Upload", children => [] },
	{ name => "SeqPrep:Cleaning", children => [] },
	{ name => "SeqPrep:Correction", children => [] },
	{ name => "SeqPrep:FastQC", children => [] },
	{ name => "SeqPrep:Flash short reads", children => [] },
	{ name => "SeqPrep:Genome size estimation", children => [] },
	{ name => "SeqPrep:Insert size estimation", children => [] },

#	{ name => "Assembly", children => [] },
	{ name => "Assembly:Masurca", children => [] },
	{ name => "Assembly:Spades", children => [] },
	{ name => "Assembly:Unicycler", children => [] },

#	{ name => "Annotation", children => [] },
	{ name => "Annotation:GenDB", children => [] },
	{ name => "Annotation:Antismash", children => [] },
	{ name => "Annotation:Arts", children => [] },
	{ name => "Annotation:Edgar", children => [] },
	];

    my $stepsize = 20;
    my $counter  = 0;
    create_tree($structure, $top_uri, $project, $apikey, $settings, $stepsize, \$counter);

    return $top_wp;
}

sub create_tree
{
    my ($structure, $top_uri, $project, $apikey, $settings, $stepsize, $counter) = @_;

    foreach my $act_item (@{$structure})
    {
	${$counter}++;
	my $wp_name = sprintf("[%03d] %s", ${$counter}*$stepsize, $act_item->{name});
	my $new_uri = create_child_wp($top_uri, $project, $apikey, $wp_name, $settings);
	# check if children are existing
	if (exists $act_item->{children} && ref($act_item->{children}) eq "ARRAY" && @{$act_item->{children}}>0)
	{
	    create_tree($act_item->{children}, $new_uri, $project, $apikey, $settings, $stepsize, $counter);
	}
    }
}

sub create_child_wp
{
    my ($parent_uri, $project, $apikey, $new_name, $settings) = @_;

    my $u = URI->new($parent_uri);
    my $base_uri=$u->scheme."://".$u->host_port;

    my $new = create_wp_4_project($base_uri, $project, $new_name, $apikey, $settings);
    my $new_uri = $base_uri.$new->{_links}{self}{href};

    add_parent($new_uri, $apikey, $parent_uri);

    return $new_uri;

}

sub add_parent
{
    my ($uri, $apikey, $parent_uri) = @_;

    my $u = URI->new($uri);
    my $base_uri=$u->scheme."://".$u->host_port;

    my $wp = get_wp_from_uri($uri, $apikey);

    my $request = HTTP::Request->new(PATCH => $base_uri.$wp->{_links}{changeParent}{href}."?notify=false");
    $request->header("Content_Type" => 'application/json');
    $request->authorization_basic('apikey', $apikey);
    my $data = {
	"lockVersion" => $wp->{lockVersion},
	"_links" => {
	    "parent" => {
		"href" => $parent_uri
	    },
	},
    };
    $request->content(to_json($data));
    $request->header("Content-Length" => length($request->content));

    my $ua = LWP::UserAgent->new();
    my $response = $ua->request($request);

    my $dat = decode_json($response->decoded_content());

    return $dat;
}

sub find_category
{
    my ($url, $apikey, $category, $project) = @_;
    my $ua = LWP::UserAgent->new();

    my $u = URI->new($url);
    my $base_uri=$u->scheme."://".$u->host_port;
    my $request = GET $base_uri.$project->{_links}{categories}{href};

    $request->authorization_basic('apikey', $apikey);

    my $response = $ua->request($request);

    my $dat = decode_json($response->decoded_content());
    my $category_href;

    foreach my $current_cat (@{$dat->{_embedded}{elements}})
    {
	if (exists $current_cat->{name} && $current_cat->{name} && $current_cat->{name} eq $category)
	{
	    $category_href = $current_cat->{_links}{self}{href};
	    last;
	}
    }

    return $category_href;
}

sub find_project
{
    my ($url, $apikey, $projectid) = @_;
    my $ua = LWP::UserAgent->new();

    my $request = GET $url.'/api/v3/projects';

    $request->authorization_basic('apikey', $apikey);

    my $response = $ua->request($request);

    my $dat = decode_json($response->decoded_content());

    # filter for a project with the projectid
    my @allprojects = @{$dat->{'_embedded'}{elements}};
    my @projects = grep { exists $_->{identifier} && $_->{identifier} && $_->{identifier} eq $projectid } (@allprojects);

    if (@projects != 1)
    {
	die
    };

    return $projects[0];
}

sub find_user
{
    my ($url, $apikey, $username) = @_;
    my $ua = LWP::UserAgent->new();

    my $user = undef;

    foreach my $uid (1..1000)
    {
	my $request = GET $url.'/api/v3/users/'.$uid;

	$request->authorization_basic('apikey', $apikey);

	my $response = $ua->request($request);

	my $dat = decode_json($response->decoded_content());

	if (exists $dat->{name} && $dat->{name} && $dat->{name} eq $username)
	{
	    $user = $dat->{_links}{self}{href};
	    last;
	}
    }

    return $user;
}


get '/' => sub {
    template 'index' => { 'title' => 'BioInf::ServiceWS' };
};

get '/bgc' => sub {
    template 'bgc';
};

get '/arts' => sub {
    forward '/bgc';
};

get '/antismash' => sub {
    forward '/bgc';
};

get '/arts/:id/**' => sub {

    my $id   = route_parameters->get('id');
    my ($tags) = splat;

    if ($tags->[0] eq "static")
    {
	my $filename = join("/", @{$tags});
	send_file 'arts/'.$filename;

    }
    elsif ($tags->[0] eq "results")
    {
	return template 'arts',{ jobid => $id }, { layout => undef };
    }
    elsif ($tags->[0] eq "antismash")
    {
	my @filelocation = @{$tags};
	shift @filelocation;
	my $file = '/run/'.$id.'/antismash/content/'.join('/', @filelocation);
	if (-e $file)
	{
	    send_file($file, system_path => 1);
	}
    }
    elsif ($tags->[0] eq "export")
    {
	my $file='/run/'.$id.'/arts/results/'.$tags->[1];

	if (-e $file)
	{
	    send_file($file, system_path => 1);
	}
    }
    elsif ($tags->[0] eq "xlfile")
    {
	my $file='/run/'.$id.'/arts/results/'.$tags->[0];

	if (-e $file)
	{
	    send_file($file, system_path => 1);
	}
    }
    elsif ($tags->[0] eq "tables")
    {
	my $file='/run/'.$id.'/arts/results/tables/'.$tags->[1];

	if (-e $file)
	{
	    send_file($file, system_path => 1);
	}
    }
    elsif ($tags->[0] eq "trees")
    {
	my $file='/run/'.$id.'/arts/results/trees/'.$tags->[1].".tree";

	if ($tags->[1] eq "speciesmlst")
	{
	    $file='/run/'.$id.'/arts/results/trees/SpeciesMLST.tree';
	}
	if (-e $file)
	{
	    use Bio::TreeIO;

	    my $in = new Bio::TreeIO(-file => $file,
				     -format => 'newick');
	    my $output = "";
	    open(my $fh, ">", \$output) || die;
	    my $out = new Bio::TreeIO(-fh => $fh,
				      -format => 'svggraph',
				      -width  => 2400,
				      -margin => 200,
		);

	    while( my $tree = $in->next_tree ) {
		$out->write_tree($tree);
	    }
	    close($fh) || die;

	    content_type 'svg';

	    return $output;
	}
    }
    elsif ($tags->[0] =~ /log/)
    {
	my $file = '/run/'.$id.'/arts/results/arts-query.log';

	if (-e $file)
	{
	    send_file($file, system_path => 1, content_type => 'text/plain');
	} else {
	    status 404;
	}
    }
    elsif ($tags->[0] =~ /krtab/)
    {
	my $content = serve_arts_file('/run/'.$id.'/arts/results/tables/knownhits.json');

	if ($content)
	{
	    return $content;
	} else {
	    status 404;
	}
    }
    elsif ($tags->[0] =~ /dupmatrix/)
    {
	my $content = serve_arts_file('/run/'.$id.'/arts/results/tables/duptable.json');

	if ($content)
	{
	    return $content;
	} else {
	    status 404;
	}
    }
    elsif ($tags->[0] =~ /bgctable/)
    {
	my $content = serve_arts_file('/run/'.$id.'/arts/results/tables/bgctable.json');

	if ($content)
	{
	    return $content;
	} else {
	    status 404;
	}
    }
    elsif ($tags->[0] =~ /funcstats/)
    {
	my $content = serve_arts_file('/run/'.$id.'/arts/results/tables/coretable.json');

	if ($content)
	{
	    my $dat = from_json($content);
	    return to_json($dat->{funcstats});
	} else {
	    status 404;
	}
    }
    elsif ($tags->[0] =~ /summarytab/)
    {
	my $content = serve_arts_file('/run/'.$id.'/arts/results/tables/coretable.json');

	if ($content)
	{
	    return $content;
	} else {
	    status 404;
	}
    }
    elsif ($tags->[0] eq "status")
    {
	my $file = '/run/'.$id.'/arts/results/arts-query.log';

	my $status = {
	    "id"         => $id,
	    "state"      => "",
	    "start"      => "",
	    "end"        => "",
	    "orgname"    => $id,
	    "jobtitle"   => $id,
	    "step"       => "",
	    "tsteps"     => 5,
	    "buildtree"  => 0,
	    "coretotal"  => "N/A",
	    "cdscount"   => "N/A",
	    "bgccount"   => "N/A",
	    "dupcount"   => "N/A",
	    "phylcount"  => "N/A",
	    "proxcount"  => "N/A",
	    "twocount"   => "N/A",
	    "threecount" => "N/A",
	    "krhits"     => "N/A",
	};

	if (-e $file)
	{
	    my ($error, $warning, $buildtree) = (0, 0, 0);
	    open(FH, "<", $file) || die "Unable to open file $file: $!\n";
	    while(<FH>)
	    {
		chomp;

		$error++ if (/ERROR/);
		$warning++ if (/WARNING/);

		$status->{state}       = "Done" if (/SUCCESS!/);
		$status->{orgname}     = $1     if (/query: org=(.+)/);
		$status->{dupcount}    = $1     if (/(\d+) duplicate genes/);
		$status->{proxcount}   = $1     if (/Proximity hits found: (\d+)/);
		$status->{twocount}    = $1     if (/Hits with two or more criteria: (\d+)/);
		$status->{threecount}  = $1     if (/Hits with three or more criteria: (\d+)/);
		$status->{krhits}      = $1     if (/Known Resistance Hits: (\d+)/);
		$status->{phylcount}   = $1     if (/Phylogeny hits found: (\d+)/);

		$status->{coretotal}   = $1     if (/Wrote \(1 of (\d+)/);

		($status->{cdscount}, $status->{bgccount}) = ($1, $2) if (/CDS features: (\d+); Clusters: (\d+)/);

		$buildtree++ if(/BuildTree: Finished/);
	    }
	    close(FH) || die "Unable to close file $file: $!\n";
	    if ($status->{state} eq "Done")
	    {
		$status->{ptitle} = "100% Complete";
		$status->{pwidth} = 100;
	    }
	    if ($error || $warning)
	    {
		$status->{ptitle} = sprintf("%s with %s errors and %s warnings", $status->{ptitle}, $error, $warning);
	    }

	    $status->{buildtree} = int($buildtree/$status->{coretotal});
	}

	return to_json($status);
    }
    else
    {
	status 404;
    }
};

sub serve_arts_file
{
    my ($file2serve) = @_;

    if (-e $file2serve)
    {
	open(FH, "<", $file2serve)||die;
	my @dat = <FH>;
	close(FH) || die;
	return join("", @dat);
    } else {
	return;
    }
}

post '/bgc' => sub {

    my $all_uploads = request->uploads;

    use Data::Dumper;
    print Dumper({request->params});
    print Dumper($all_uploads);

    my $sizeinbyte = request->upload('upload')->size;
    my $size       = human_readable_size($sizeinbyte);
    my $filename   = request->upload('upload')->filename;
    my $tempname   = request->upload('upload')->tempname;
    my $email      = request->param('email');
    my $jobname    = request->param('jobname');
    my $borderpred = request->param('borderpredict');
    if (defined ($borderpred) && $borderpred eq "activated")
    {
	$borderpred = 1;
    } else {
	$borderpred = 0;
    }
	

    my ($origfilename, $origdirs, $origsuffix) = fileparse($filename, qr/\.[^.]+$/);

    # calculate a checksum for the uploaded file
    my $checksum = generate_md5($tempname);

    # generate the jobid based on email, filename, size and checksum of the input file
    my $timestamp = time;
    my $jobid    = get_jobid($email, $filename, $sizeinbyte, $checksum, $timestamp);

    # store file
    my $jobfolder   = "/upload/$jobid";
    mkdir $jobfolder || die "Unable to create $jobfolder: $!\n";
    my $jobfile     = "content".$origsuffix;
    my $jobfile_complete = $jobfolder."/".$jobfile;
    my $jobmetafile = $jobfolder."/metadata.json";

    my $metadata = {
	jobname     => $jobname,
	email       => $email,
	filename    => $filename,
	size        => $sizeinbyte,
	checksum    => $checksum,
	timestamp   => $timestamp,
	jobfilename => $jobfile,
	version     => $VERSION,
	prog2run    => {
	    "antismash" => \1,
	    "arts"      => \1,
	    "borderpredict" => \$borderpred
	    },
    };
    request->upload('upload')->copy_to($jobfile_complete);
    open(FH, ">", $jobmetafile) || die "Unable to open '$jobmetafile': $!\n";
    print FH to_json($metadata);
    close(FH) || die "Unable to close '$jobmetafile': $!\n";

    template upload => { jobname => $jobname, jobfilename => $jobfile, filename => $filename, size => $size, email => $email, jobid => $jobid, analysisname => "BGC", checksum => $checksum };
};

sub generate_md5
{
    my ($filename) = @_;

    my $ctx = Digest::MD5->new;

    open(FH, "<", $filename) || die "Unable to open file: '$filename': $!\n";
    while(<FH>)
    {
	$ctx->add($_);
    }
    close(FH) || die "Unable to close file: '$filename': $!\n";

    return $ctx->hexdigest;
}

sub get_jobid
{
    my ($email, $filename, $size, $checksum, $timestamp) = @_;

    my $key = "hrqfsV"; # random value
    my $data = join("\t", $email, $filename, $size, $checksum, $timestamp);

    my $jobid =  hmac_sha256_hex($data, $key);

    return($jobid);
}

sub human_readable_size
{
    my ($size) = @_;

    my %prefix = (
	"G" => 2**30,
	"M" => 2**20,
	"K" => 2**10,
	""  => 2**0,
	);
    my @order = sort {$prefix{$b} <=> $prefix{$a} } (keys %prefix);

    my $prefix_estimated = "";
    foreach (@order)
    {
	if ($size/$prefix{$_}>1)
	{
	    $prefix_estimated = $_;
	    last;
	}
    }

    my $human_size;
    my $number_format = "%d %sByte";
    if ($prefix_estimated)
    {
	$number_format = "%.1f %sByte";
    }
    $human_size = sprintf($number_format, ($size/$prefix{$prefix_estimated}), $prefix_estimated);

    return $human_size;
}

true;
