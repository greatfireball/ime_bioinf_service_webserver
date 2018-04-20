package BioInf::ServiceWS;
use Dancer2;

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
    
    template upload => { filename => $filename, size => $size, email => $email, jobid => $jobid, analysisname => "ARTS" };
};

true;
