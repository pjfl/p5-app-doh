package App::Doh::Role::Authorization;

use attributes ();
use namespace::autoclean;

use Class::Usul::Constants qw( NUL );
use Class::Usul::Functions qw( is_member throw );
use HTTP::Status           qw( HTTP_FORBIDDEN HTTP_NOT_FOUND
                               HTTP_UNAUTHORIZED );
use Scalar::Util           qw( blessed );
use Moo::Role;

requires qw( config execute );

around 'execute' => sub {
   my ($orig, $self, $method, $req) = @_; my $class = blessed $self || $self;

   my $code_ref = $self->can( $method )
      or  throw error => 'Class [_1] has no method [_2]',
                args  => [ $class, $method ], rv => HTTP_NOT_FOUND;

   my $method_roles = __list_roles_of( $code_ref ); $method_roles->[ 0 ]
      or  throw error => 'Class [_1] method [_2] is private',
                args  => [ $class, $method ], rv => HTTP_FORBIDDEN;

   is_member 'anon', $method_roles and return $orig->( $self, $method, $req );

   $req->username eq 'unknown'
      and throw error => 'Class [_1] method [_2] authorization required',
                 args => [ $class, $method ], rv => HTTP_UNAUTHORIZED;

   is_member 'any', $method_roles and return $orig->( $self, $method, $req );

   my $conf = $self->config;

   for my $role_name (@{ $conf->user_roles->{ $req->username } // [] }) {
      is_member $role_name, $method_roles
         and return $orig->( $self, $method, $req );
   }

   throw error => 'User [_1] permission denied',
         args  => [ $req->username ], rv => HTTP_FORBIDDEN;
   return; # Never reached
};

sub __list_roles_of {
   my $attr = attributes::get( shift ) // {}; return $attr->{Role} // [];
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
