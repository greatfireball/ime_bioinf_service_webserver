packagen BioInf::ServiceWS::API;
use Dancer2;

set serializer => 'JSON';

get '/openproject_categories' => sub {
    my $data = {};

    return $data;
}

1;
