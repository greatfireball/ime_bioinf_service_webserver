#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";


# use this block if you don't need middleware, and only have a single target Dancer app to run here
use BioInf::ServiceWS;

BioInf::ServiceWS->to_app;

=begin comment
# use this block if you want to include middleware such as Plack::Middleware::Deflater

use BioInf::ServiceWS;
use Plack::Builder;

builder {
    enable 'Deflater';
    BioInf::ServiceWS->to_app;
}

=end comment

=cut

=begin comment
# use this block if you want to mount several applications on different path

use BioInf::ServiceWS;
use BioInf::ServiceWS_admin;

use Plack::Builder;

builder {
    mount '/'      => BioInf::ServiceWS->to_app;
    mount '/admin'      => BioInf::ServiceWS_admin->to_app;
}

=end comment

=cut

