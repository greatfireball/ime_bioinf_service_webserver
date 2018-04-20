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
};

true;
