#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";


use BioInf::ServiceWS;
use BioInf::ServiceWS::API;

use Plack::Builder;

builder {
    mount '/'        => BioInf::ServiceWS->to_app;
    mount '/api'     => BioInf::ServiceWS::API->to_app;
}


