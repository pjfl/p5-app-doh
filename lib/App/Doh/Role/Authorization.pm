package App::Doh::Role::Authorization;

use attributes ();
use namespace::autoclean;

use Class::Usul::Constants qw( NUL );
use Class::Usul::Functions qw( is_member throw );
use HTTP::Status           qw( HTTP_FORBIDDEN HTTP_NOT_FOUND
                               HTTP_UNAUTHORIZED );
use Scalar::Util           qw( blessed );
use Moo::Role;

requires qw( execute );

around 'execute' => sub {
   my ($orig, $self, $method, $req) = @_; my $class = blessed $self || $self;

   $self->can( $method )
      or throw error => 'Class [_1] has no method [_2]',
               args  => [ $class, $method ], rv => HTTP_NOT_FOUND;

   my $method_roles = $self->_list_roles_of( $method );

   $method_roles->[ 0 ]
      or throw error => 'Method [_1] is private',
               args  => [ $method ], rv => HTTP_FORBIDDEN;

   is_member 'any', $method_roles and return $orig->( $self, $method, $req );

   $req->username eq 'unknown'
      and throw error => 'Authentication required', rv => HTTP_UNAUTHORIZED;

   my $conf = $self->config;

   for my $role_name (@{ $conf->user_roles->{ $req->username } // [] }) {
      is_member $role_name, $method_roles
         and return $orig->( $self, $method, $req );
   }

   throw error => 'User [_1] permission denied',
         args  => [ $req->username ], rv => HTTP_FORBIDDEN;
   return; # Never reached
};

sub _list_roles_of {
   my ($self, $method) = @_; my $class = blessed $self || $self;

   my $code_ref = $self->can( $method ) or return ();

   return [ map  { m{ \A Role [\(] ([^\)]+) [\)] \z }mx }
            grep { m{ \A Role }mx } @{ attributes::get( $code_ref ) || [] } ];
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
