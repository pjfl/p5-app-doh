package App::Doh::View::HTML;

use namespace::autoclean;

use App::Doh::Util         qw( stash_functions );
use Class::Usul::Constants qw( TRUE );
use Encode                 qw( encode );
use File::DataClass::Types qw( CodeRef HashRef Object );
use HTML::GenerateUtil     qw( escape_html );
use Web::Components::Util  qw( load_components );
use Moo;

with 'Web::Components::Role';
with 'Web::Components::Role::TT';

# Public attributes
has '+moniker'   => default => 'html';

has 'formatters' => is => 'lazy', isa => HashRef[Object],
   builder       => sub { load_components 'View::HTML', application => $_[0] };

has 'type_map'   => is => 'lazy', isa => HashRef, builder => sub {
   my $self = shift; my $map = { htm => 'html', html => 'html' };

   for my $moniker (keys %{ $self->formatters }) {
      for my $extn (@{ $self->formatters->{ $moniker }->extensions }) {
         $map->{ $extn } = $moniker;
      }
   }

   return $map;
};

# Private functions
my $_header = sub {
   return [ 'Content-Type' => 'text/html', @{ $_[ 0 ] || [] } ];
};

# Public methods
sub serialize {
   my ($self, $req, $stash) = @_; stash_functions $self, $req, $stash;

   my $html = encode( $self->encoding, $self->render_template( $stash ) );

   return [ $stash->{code}, $_header->( $stash->{http_headers} ), [ $html ] ];
}

around 'serialize' => sub {
   my ($orig, $self, $req, $stash) = @_; my $page = $stash->{page} //= {};

   defined $page->{format} or return $orig->( $self, $req, $stash );

   $page->{format} eq 'text'
      and $page->{content} = '<pre>'.escape_html( $page->{content} ).'</pre>'
      and $page->{format } = 'html'
      and return $orig->( $self, $req, $stash );

   my $formatter = $self->formatters->{ $page->{format} };

   $formatter and $page->{content} = $formatter->serialize( $req, $page )
              and $page->{format } = 'html';

   return $orig->( $self, $req, $stash );
};

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
