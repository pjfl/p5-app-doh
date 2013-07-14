# @(#)Ident: 10test_script.t 2013-07-13 23:32 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 2 $ =~ /\d+/gmx );
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

use Data::Dumper; $Data::Dumper::Terse    = 1; $Data::Dumper::Indent = 1;
                  $Data::Dumper::Sortkeys = sub { [ sort keys %{ $_[ 0 ] } ] };

use_ok 'Daux';

my $self  = Daux->new;
my $model = $self->model;
my $tree  = $model->docs_tree;

ok exists $tree->{Getting_Started}, 'Creates docs tree';

my $stash = $model->get_stash( 'Getting_Started' );

warn Dumper( $stash );

my $res   = $self->html_view->render( $stash );

warn Dumper( $res->[ 1 ] );

done_testing;

#SKIP: {
#   $reason and $reason =~ m{ \A tests: }mx and skip $reason, 1;
#}

# Local Variables:
# mode: perl
# tab-width: 3
# End:
