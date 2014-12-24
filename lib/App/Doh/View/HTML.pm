package App::Doh::View::HTML;

use namespace::autoclean;

use Moo;
use App::Doh::Functions    qw( load_components );
use Class::Usul::Constants qw( TRUE );
use Encode                 qw( encode );
use File::DataClass::Types qw( HashRef Object );

with q(App::Doh::Role::Component);
with q(App::Doh::Role::Templates);

# Public attributes
has '+moniker'   => default => 'html';

has 'formatters' => is => 'lazy', isa => HashRef[Object], builder => sub {
   load_components 'View::HTML', $_[ 0 ]->usul->config,
      { builder => $_[ 0 ]->usul, } };

has 'type_map' => is => 'lazy', isa => HashRef, builder => sub {
   my $self = shift; my $map = { htm => 'html', html => 'html' };

   for my $format (keys %{ $self->formatters }) {
      for my $extn (@{ $self->formatters->{ $format }->extensions }) {
         $map->{ $extn } = $format;
      }
   }

   return $map;
};

# Private functions
my $_header = sub {
   return [ 'Content-Type' => 'text/html', @{ $_[ 0 ] || [] } ];
};

# Private methods
my $_serialize_microformat = sub {
   my ($self, $req, $page) = @_; defined $page->{format} or return;

   $page->{format} eq 'text'
      and $page->{content} = '<pre>'.$page->{content}.'</pre>'
      and $page->{format } = 'html'
      and return;

   my $formatter = $self->formatters->{ $page->{format} } or return;

   $page->{content} = $formatter->serialize( $req, $page )
      and $page->{format} = 'html';

   return;
};

# Public methods
sub serialize {
   my ($self, $req, $stash) = @_; my $enc = $self->encoding;

   $self->$_serialize_microformat( $req, $stash->{page} //= {} );

   my $html = encode( $enc, $self->render_template( $req, $stash ) );

   return [ $stash->{code}, $_header->( $stash->{http_headers} ), [ $html ] ];
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
