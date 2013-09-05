# @(#)Ident: 10test_script.t 2013-08-21 23:47 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 20 $ =~ /\d+/gmx );
use File::Spec::Functions   qw( catdir updir );
use FindBin                 qw( $Bin );
use lib                 catdir( $Bin, updir, 'lib' );

use Module::Build;
use Test::More;

my $notes = {}; my $perl_ver;

BEGIN {
   my $builder = eval { Module::Build->current };
      $builder and $notes = $builder->notes;
      $perl_ver = $notes->{min_perl_version} || 5.008;
}

use Test::Requires "${perl_ver}";

use_ok 'App::Doh';

my $self  = App::Doh->new;
my $model = $self->model;
my $tree  = $model->docs_tree;
my $stash = $model->get_stash( 'Getting_Started' );
my $res   = $self->html_view->render( $stash );

ok exists $tree->{Getting_Started}, 'Creates docs tree';
is $model->docs_url, '/Getting_Started', 'Docs url';

#$self->usul->dumper( $stash );

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
