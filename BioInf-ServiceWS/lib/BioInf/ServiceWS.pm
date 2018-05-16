package BioInf::ServiceWS;
use Dancer2;
use Digest::SHA qw(hmac_sha256_hex);
use Digest::MD5;
use File::Basename;

our $VERSION = '0.1';

get '/' => sub {
    template 'index' => { 'title' => 'BioInf::ServiceWS' };
};

get '/bgc' => sub {
    template 'bgc';
};

get '/arts' => sub {
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
    elsif ($tags->[0] eq "trees")
    {
	my $content = serve_arts_file('/run/'.$id.'/arts/results/trees/'.$tags->[1].".tree");

	if ($content)
	{
	    return $content;
	} else {
	    status 404;
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
	return to_json({state => "Done"});
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
	prog2run    => [
	    "antismash" => \1,
	    "arts"      => \1,
	    ],
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
