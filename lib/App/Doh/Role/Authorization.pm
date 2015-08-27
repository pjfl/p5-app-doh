package App::Doh::Role::Authorization;

use attributes ();
use namespace::autoclean;

use Class::Usul::Constants qw( NUL );
use Class::Usul::Functions qw( is_member throw );
use HTTP::Status           qw( HTTP_FORBIDDEN HTTP_NOT_FOUND
                               HTTP_UNAUTHORIZED );
use Scalar::Util           qw( blessed );
use Moo::Role;

requires qw( config execute users );

# Private functions
my $_list_roles_of = sub {
   my $attr = attributes::get( shift ) // {}; return $attr->{Role} // [];
};

# Construction
around 'execute' => sub {
   my ($orig, $self, $method, $req) = @_; my $class = blessed $self || $self;

   my $code_ref = $self->can( $method )
      or throw 'Class [_1] has no method [_2]', [ $class, $method ],
               rv => HTTP_NOT_FOUND;

   my $method_roles = $_list_roles_of->( $code_ref ); $method_roles->[ 0 ]
      or throw 'Class [_1] method [_2] is private', [ $class, $method ],
               rv => HTTP_FORBIDDEN;

   ($req->mode eq 'static' or is_member 'anon', $method_roles)
      and return $orig->( $self, $method, $req );

   $req->authenticated or throw 'Resource [_1] authentication required',
                                [ $req->path ], rv => HTTP_UNAUTHORIZED;

   is_member 'any', $method_roles and return $orig->( $self, $method, $req );

   my $user = $self->users->find( $req->username );

   for my $role_name (@{ $user->roles // [] }) {
      is_member $role_name, $method_roles
         and return $orig->( $self, $method, $req );
   }

   throw 'User [_1] permission denied', [ $req->username ],
         rv => HTTP_FORBIDDEN;
};

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
