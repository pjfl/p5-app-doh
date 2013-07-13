# @(#)Ident: 10test_script.t 2013-05-19 11:50 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 1 $ =~ /\d+/gmx );
use File::Spec::Functions   qw( catdir updir );
use FindBin                 qw( $Bin );
use lib                 catdir( $Bin, updir, q(lib) );

use Module::Build;
use Test::More;

my $reason;

BEGIN {
   my $builder = eval { Module::Build->current };

   $builder and $reason = $builder->notes->{stop_tests};
   $reason  and $reason =~ m{ \A TESTS: }mx and plan skip_all => $reason;
}

use_ok 'Daux';

#SKIP: {
#   $reason and $reason =~ m{ \A tests: }mx and skip $reason, 1;
#}

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
