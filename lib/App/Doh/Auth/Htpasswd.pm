package App::Doh::Auth::Htpasswd;

use strict;
use warnings;
use parent 'Plack::Middleware::Auth::Htpasswd';

use Class::Usul::Functions qw( throw );
use Plack::Request;
use Plack::Util::Accessor  qw( params );

sub prepare_app {
    my $self = shift;

    (defined $self->params and ref $self->params eq 'ARRAY')
       or throw 'Must specify an array ref of parameters';

    return $self->SUPER::prepare_app;
}

sub call {
   my($self, $env) = @_;

   my $params = Plack::Request->new( $env )->query_parameters;

   for my $name (@{ $self->params }) {
      exists $params->{ $name } and $params->{ $name }
         and return $self->SUPER::call( $env );
   }

   return $self->app->( $env );
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
