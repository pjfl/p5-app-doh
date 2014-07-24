package App::Doh::View::HTML;

use namespace::autoclean;

use Moo;
use App::Doh::Functions    qw( load_components );
use Class::Usul::Constants qw( TRUE );
use Encode                 qw( encode );
use File::DataClass::Types qw( Directory HashRef Object );
use Module::Pluggable::Object;

with q(App::Doh::Role::Component);
with q(App::Doh::Role::Templates);

# Public attributes
has '+moniker'   => default => 'html';

has 'formatters' => is => 'lazy', isa => HashRef[Object], builder => sub {
   load_components __PACKAGE__, { builder => $_[ 0 ]->usul, min_depth => 4 } };

has 'type_map' => is => 'lazy', isa => HashRef, builder => sub {
   my $self = shift; my $map = { htm => 'html', html => 'html' };

   for my $format (keys %{ $self->formatters }) {
      for my $extn (@{ $self->formatters->{ $format }->extensions }) {
         $map->{ $extn } = $format;
      }
   }

   return $map;
};

# Public methods
sub serialize {
   my ($self, $req, $stash) = @_;

   $self->_serialize_microformat( $req, $stash->{page} //= {} );

   my $html = encode( 'UTF-8', $self->render_template( $req, $stash ) );

   return [ $stash->{code}, __header( $stash->{http_headers} ), [ $html ] ];
}

# Private methods
sub _serialize_microformat {
   my ($self, $req, $page) = @_; defined $page->{format} or return;

   $page->{format} eq 'text'
      and $page->{content} = '<pre>'.$page->{content}.'</pre>'
      and $page->{format } = 'html'
      and return;

   my $formatter = $self->formatters->{ $page->{format} } or return;

   $page->{content} = $formatter->serialize( $req, $page )
      and $page->{format} = 'html';

   return;
}

# Private functions
sub __header {
   return [ 'Content-Type' => 'text/html', @{ $_[ 0 ] || [] } ];
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
