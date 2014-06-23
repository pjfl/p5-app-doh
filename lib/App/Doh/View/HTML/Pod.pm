package App::Doh::View::HTML::Pod;

use namespace::autoclean;

use Moo;
use Class::Usul::Constants qw( TRUE );
use Class::Usul::Types     qw( ArrayRef NonEmptySimpleStr Object );
use HTML::Accessors;
use Pod::Hyperlink::BounceURL;
use Pod::Xhtml;

extends q(App::Doh);

$Pod::Xhtml::COMMANDS{encoding} = TRUE; # STFU

# Public attributes
has 'extensions' => is => 'lazy', isa => ArrayRef,
   builder       => sub { $_[ 0 ]->config->extensions->{pod} };

has 'link_text'  => is => 'ro',   isa => NonEmptySimpleStr,
   default       => 'Back to Top';

# Private attributes
has '_hacc'      => is => 'lazy', isa => Object,
   builder       => sub { HTML::Accessors->new( content_type => 'text/html' ) };

# Public methods
sub serialize {
   my ($self, $req, $page) = @_;

   my $hacc        = $self->_hacc;
   my $content     = $page->{content};
   my $header      = $hacc->a( { id => 'podtop' } );
   my $link_parser = Pod::Hyperlink::BounceURL->new;
      $link_parser->configure( URL => $page->{url} );
   my $parser      = Pod::Xhtml->new
      (  FragmentOnly => TRUE,
         LinkParser   => $link_parser,
         StringMode   => TRUE,
         TopHeading   => 1,
         TopLinks     => $self->_top_link( $req ), );

   $content and $content->exists
      and $parser->parse_from_file( $content->pathname );
   $content = $parser->asString || $self->_error( $req, $content );
   # Setting TopHeading = 2 screws the indent level in the index
   $content =~ s{ <   h (\d) }{"<h"  . ( $1 + 1 ) }egmx;
   $content =~ s{ < / h (\d) }{"</h" . ( $1 + 1 ) }egmx;
   return $header.$content;
}

# Private methods
sub _error {
   my ($self, $req, $path) = @_;

   my $error = $req->loc( 'Class [_1] has no POD', $path->filename );

   return $self->_hacc->pre( $error );
}

sub _top_link {
   my ($self, $req) = @_; my $hacc = $self->_hacc;

   my $attr = { class => 'toplink', href => '#podtop' };
   my $link = $hacc->a( $attr, $req->loc( $self->link_text ) );

   return $hacc->p( { class => 'toplink' }, $link );
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
