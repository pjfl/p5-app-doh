# @(#)Ident: 10test_script.t 2013-11-28 17:48 pjf ;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 23 $ =~ /\d+/gmx );
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

use_ok 'App::Doh::Server';

my $self  = App::Doh::Server->new;
my $model = $self->doc_model;
my $tree  = $model->docs_tree;

ok exists $tree->{Getting_Started}, 'Creates docs tree';

my $req   = App::Doh::Request->new( $self->usul, 'Getting_Started' );
my $stash = $model->get_stash( $req );
my $res   = $self->html_view->render( $req, $stash );

is $model->docs_url, 'Getting_Started', 'Docs url';

#$self->usul->dumper( $req );
#$self->usul->dumper( $stash );
#$self->usul->dumper( $res );

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
