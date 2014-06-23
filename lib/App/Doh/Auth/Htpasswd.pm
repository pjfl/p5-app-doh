package App::Doh::Auth::Htpasswd;

use strictures;
use parent 'Plack::Middleware::Auth::Htpasswd';

sub call {
   my($self, $env) = @_;

   $ENV{DOH_MAKE_STATIC} or return $self->SUPER::call( $env );

   return $self->app->( $env );
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
