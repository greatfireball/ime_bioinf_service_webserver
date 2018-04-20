package BioInf::ServiceWS;
use Dancer2;
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

    my $size     = request->upload('upload')->size;
    my $filename = request->upload('upload')->filename;
    my $tempname = request->upload('upload')->tempname;
    my $email    = request->param('email');
    my $jobid    = 42;

    # calculate a checksum for the uploaded file
    my $checksum = generate_md5($tempname);

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

true;
