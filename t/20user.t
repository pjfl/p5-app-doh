use t::boilerplate;

use Test::More;
use Test::Requires { 'warnings::illegalproto' => 0.001000 };

use_ok 'App::Doh::Server';

my $self  = App::Doh::Server->new( config => { appclass => 'App::Doh' } );
my $users = $self->models->{admin}->users;

$users->find( 'admin') and $users->delete( 'admin' );

my $user  = $users->create( {
   email    => 'Admin@example.com', id => 'admin',
   password => 'admin123', roles => [ 'admin', 'editor', 'user' ] } );

is $user->email, 'Admin@example.com', 'Creates user';

$users->update( { id => 'admin', active => 1 } );

ok $users->find( 'admin' )->active, 'Activates user';

done_testing;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
