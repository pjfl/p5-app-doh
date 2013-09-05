# @(#)Ident: Pod.pm 2013-09-05 11:16 pjf ;

package App::Doh::View::HTML::Pod;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 14 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Types      qw( ArrayRef NonEmptySimpleStr Object Str );
use HTML::Accessors;
use Moo;
use Pod::Hyperlink::BounceURL;
use Pod::Xhtml;

extends q(App::Doh);

$Pod::Xhtml::COMMANDS{encoding} = TRUE; # STFU

has 'extensions' => is => 'ro', isa => ArrayRef,
   default       => sub { [ qw( pl pm pod ) ] };

has 'link_text'  => is => 'ro',   isa => NonEmptySimpleStr,
   default       => 'Back to Top';


has '_hacc'      => is => 'lazy', isa => Object,
   default       => sub { HTML::Accessors->new( content_type => 'text/html' ) };

has '_top_link'  => is => 'lazy', isa => Str;

sub render {
   my ($self, $page) = @_;

   my $hacc        = $self->_hacc;
   my $content     = $page->{content};
   my $anchor      = $hacc->a( { id => 'podtop' } );
   my $title       = $hacc->h1( $page->{title} );
   my $heading     = $anchor.$hacc->div( { class => 'page-header' }, $title );
   my $link_parser = Pod::Hyperlink::BounceURL->new;
      $link_parser->configure( URL => $page->{url} );
   my $parser      = Pod::Xhtml->new( FragmentOnly => TRUE,
                                      LinkParser   => $link_parser,
                                      StringMode   => TRUE,
                                      TopHeading   => 2,
                                      TopLinks     => $self->_top_link, );

   $content and $content->exists
      and $parser->parse_from_file( $content->pathname );

   return $heading.( $parser->asString || $self->_error( $content ) );
}

sub _build__top_link {
   my $self = shift;
   my $hacc = $self->_hacc;
   my $attr = { class => 'toplink', href => '#podtop' };
   my $link = $hacc->a( $attr, $self->loc( $self->link_text ) );

   return $hacc->p( { class => 'toplink' }, $link );
}

sub _error {
   my ($self, $path) = @_;

   my $error = $self->loc( 'Class [_1] has no POD', $path->filename || '[]' );

   return $self->_hacc->pre( $error );
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
