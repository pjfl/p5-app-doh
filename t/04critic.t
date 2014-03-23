use strict;
use warnings;
use File::Spec::Functions qw( catdir updir );
use FindBin               qw( $Bin );
use lib               catdir( $Bin, updir, 'lib' );

use Test::More;

BEGIN {
   $ENV{AUTHOR_TESTING} or plan skip_all => 'Critic test only for developers';
}

use English qw( -no_match_vars );

eval "use Test::Perl::Critic -profile => catfile( q(t), q(critic.rc) )";

$EVAL_ERROR and plan skip_all => 'Test::Perl::Critic not installed';

$ENV{TEST_CRITIC}
   or plan skip_all => 'Environment variable TEST_CRITIC not set';

all_critic_ok();

# Local Variables:
# mode: perl
# tab-width: 3
# End:
