# @(#)Ident: 03podcoverage.t 2013-11-29 02:31 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 24 $ =~ /\d+/gmx );
use File::Spec::Functions;
use FindBin qw( $Bin );
use lib catdir( $Bin, updir, q(lib) );

use English qw(-no_match_vars);
use Test::More;

BEGIN {
   $ENV{AUTHOR_TESTING}
      or plan skip_all => 'POD coverage test only for developers';
}

eval "use Test::Pod::Coverage 1.04";

$EVAL_ERROR and plan skip_all => 'Test::Pod::Coverage 1.04 required';

pod_coverage_ok( 'App::Doh' );
pod_coverage_ok( 'App::Doh::Config' );
pod_coverage_ok( 'App::Doh::Daemon' );
pod_coverage_ok( 'App::Doh::Request' );
pod_coverage_ok( 'App::Doh::Server' );
pod_coverage_ok( 'App::Doh' );
pod_coverage_ok( 'App::Doh' );

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
