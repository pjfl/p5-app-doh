use strict;
use warnings;
use File::Spec::Functions qw( catdir updir );
use FindBin               qw( $Bin );
use lib               catdir( $Bin, updir, 'lib' );

use Test::More;
use Test::Requires { version => 0.88 };
use Module::Build;

my $notes = {}; my $perl_ver;

BEGIN {
   my $builder = eval { Module::Build->current };
      $builder and $notes = $builder->notes;
      $perl_ver = $notes->{min_perl_version} || 5.008;
}

use Test::Requires "${perl_ver}";

use_ok 'App::Doh::Server';

my $self  = App::Doh::Server->new;
my $users = $self->models->{auth}->users;

$users->delete_user( 'admin' );

my $user  = $users->create_user( {
   fullname => 'Administrator', id => 'admin',
   password => 'admin',      roles => [ 'admin', 'editor' ] } );

is $user->fullname, 'Administrator', 'Creates user';

$users->activate_user( 'admin' );

ok $users->read_user( 'admin')->active, 'Activates user';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3: