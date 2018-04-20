package BioInf::ServiceWS;
use Dancer2;
use Digest::SHA qw(hmac_sha256_hex);
use Digest::MD5;

our $VERSION = '0.1';

get '/' => sub {
    template 'index' => { 'title' => 'BioInf::ServiceWS' };
};

get '/arts' => sub {
    template 'arts';
};

post '/arts' => sub {

    my $all_uploads = request->uploads;

    use Data::Dumper;
    print Dumper({request->params});
    print Dumper($all_uploads);

    my $sizeinbyte = request->upload('upload')->size;
    my $size       = human_readable_size($sizeinbyte);
    my $filename   = request->upload('upload')->filename;
    my $tempname   = request->upload('upload')->tempname;
    my $email      = request->param('email');

    # calculate a checksum for the uploaded file
    my $checksum = generate_md5($tempname);

    # generate the jobid based on email, filename, size and checksum of the input file
    my $jobid    = get_jobid($email, $filename, $sizeinbyte, $checksum);

    # store file
    my $jobfile     = "/upload/$jobid";
    my $jobmetafile = $jobfile.".metadata";

    my $metadata = {
	email    => $email,
	filename => $filename,
	size     => $sizeinbyte,
	checksum => $checksum,
    };
    request->upload('upload')->copy_to($jobfile);
    open(FH, ">", $jobmetafile) || die "Unable to open '$jobmetafile': $!\n";
    print FH to_json($metadata);
    close(FH) || die "Unable to close '$jobmetafile': $!\n";

    template upload => { filename => $filename, size => $size, email => $email, jobid => $jobid, analysisname => "ARTS", checksum => $checksum };
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
    my ($email, $filename, $size, $checksum) = @_;

    my $key = "hrqfsV"; # random value
    my $data = join("\t", $email, $filename, $size, $checksum, time);

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
