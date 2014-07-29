use strict;
use warnings;
use File::Spec::Functions qw( catdir updir );
use FindBin               qw( $Bin );
use lib               catdir( $Bin, updir, 'lib' );

use Module::Build;
use Test::More;

my $notes = {}; my $perl_ver;

BEGIN {
   my $builder = eval { Module::Build->current };
      $builder and $notes = $builder->notes;
      $perl_ver = $notes->{min_perl_version} || 5.008;
}

use Test::Requires "${perl_ver}";
use Test::Requires { 'warnings::illegalproto' => 0.001000 };

use_ok 'App::Doh::Server';
use_ok 'App::Doh::Request';

my $app   = App::Doh::Server->new( config => { appclass => 'App::Doh' } );
my $model = $app->models->{docs};
my $tree  = $model->docs_tree;

ok exists $tree->{en}->{tree}->{ 'Getting-Started' }, 'Creates docs tree';

my $req   = App::Doh::Request->new( $app->usul, 'Getting_Started' );

isa_ok $req, 'App::Doh::Request', 'Creates request object';

my $stash = $model->get_content( $req );
my $res   = $app->views->{html}->serialize( $req, $stash );

is $res->[ 0 ], 200, 'Reponse code';
is $res->[ 1 ]->[ 1 ], 'text/html', 'Response mime type';

#$app->usul->dumper( $req );
#$app->usul->dumper( $stash );
#$app->usul->dumper( $res );

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
