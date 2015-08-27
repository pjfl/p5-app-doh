use t::boilerplate;

use Test::More;

use_ok 'App::Doh::Server';

my $app   = App::Doh::Server->new( config => { appclass => 'App::Doh' } );
my $model = $app->models->{docs};
my $tree  = $model->docs_tree;

ok exists $tree->{en}->{tree}->{ 'Getting-Started' }, 'Creates docs tree';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
