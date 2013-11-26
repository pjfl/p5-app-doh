# @(#)Ident: Markdown.pm 2013-11-23 14:31 pjf ;

package App::Doh::View::HTML::Markdown;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 22 $ =~ /\d+/gmx );

use Moo;
use Class::Usul::Types      qw( ArrayRef Object );
use Text::Markdown;

has 'extensions' => is => 'ro', isa => ArrayRef,
   default       => sub { [ qw( md mkdn ) ] };

has 'tm'         => is => 'lazy', isa => Object,
   default       => sub { Text::Markdown->new( tab_width => 3 ) };

sub render {
   my ($self, $req, $page) = @_;

   return $self->tm->markdown( $page->{content}->utf8->all );
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
