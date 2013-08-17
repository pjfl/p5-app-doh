# @(#)Ident: 10test_script.t 2013-08-17 17:13 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 16 $ =~ /\d+/gmx );
use File::Spec::Functions   qw( catdir updir );
use FindBin                 qw( $Bin );
use lib                 catdir( $Bin, updir, q(lib) );

use Module::Build;
use Test::More;

my $notes = {};

BEGIN {
   my $builder = eval { Module::Build->current };
      $builder and $notes = $builder->notes;
}

use_ok 'Doh';

my $self  = Doh->new;
my $model = $self->model;
my $tree  = $model->docs_tree;
my $stash = $model->get_stash( 'Getting_Started' );
my $res   = $self->html_view->render( $stash );

ok exists $tree->{Getting_Started}, 'Creates docs tree';
is $model->docs_url, '/Getting_Started', 'Docs url';

#$self->usul->dumper( $stash );

done_testing;

#SKIP: {
#   $reason and $reason =~ m{ \A tests: }mx and skip $reason, 1;
#}

# Local Variables:
# mode: perl
# tab-width: 3
# End:
