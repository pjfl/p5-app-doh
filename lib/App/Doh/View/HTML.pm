package App::Doh::View::HTML;

use namespace::sweep;

use Moo;
use Class::Usul::Constants;
use Encode;
use File::DataClass::Types qw( Directory HashRef Object );
use Module::Pluggable::Object;

extends q(App::Doh);
with    q(App::Doh::Role::Templates);

# Public attributes
has 'formatters' => is => 'lazy', isa => HashRef[Object], builder => sub {
   my $self = shift; my $formatters = {};

   my $finder = Module::Pluggable::Object->new
      ( search_path => [ __PACKAGE__ ], require => TRUE, );

   for my $formatter ($finder->plugins) {
      my $format = lc ((split m{ :: }mx, $formatter)[ -1 ]);

      $formatters->{ $format } = $formatter->new( builder => $self->usul );
   }

   return $formatters;
};

has 'type_map' => is => 'lazy', isa => HashRef, builder => sub {
   my $self = shift; my $map = { htm => 'html', html => 'html' };

   for my $format (keys %{ $self->formatters }) {
      for my $extn (@{ $self->formatters->{ $format }->extensions }) {
         $map->{ $extn } = $format;
      }
   }

   return $map;
};

# Construction
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
