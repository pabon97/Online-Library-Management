package CHI::t::Sanity;
$CHI::t::Sanity::VERSION = '0.61';
use strict;
use warnings;
use CHI::Test;
use base qw(CHI::Test::Class);

sub test_ok : Tests {
    ok( 1, '1 is ok' );
}

1;
