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

use_ok 'App::Doh::Server';

my $self  = App::Doh::Server->new;
my $model = $self->models->{docs};
my $tree  = $model->docs_tree;

ok exists $tree->{en}->{tree}->{ 'Getting-Started' }, 'Creates docs tree';

my $req   = App::Doh::Request->new( $self->usul, 'Getting_Started' );
my $stash = $model->get_stash( $req );
my $res   = $self->views->{html}->serialize( $req, $stash );

#$self->usul->dumper( $req );
#$self->usul->dumper( $stash );
#$self->usul->dumper( $res );

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
