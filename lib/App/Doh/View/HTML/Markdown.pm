# @(#)Ident: Markdown.pm 2013-11-28 18:28 pjf ;

package App::Doh::View::HTML::Markdown;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 23 $ =~ /\d+/gmx );

use Moo;
use Class::Usul::Types      qw( ArrayRef Object );
use Text::Markdown;

extends q(App::Doh);

has 'extensions' => is => 'lazy', isa => ArrayRef,
   builder       => sub { $_[ 0 ]->config->extensions->{markdown} };

has 'tm'         => is => 'lazy', isa => Object,
   builder       => sub { Text::Markdown->new( tab_width => 3 ) };

sub render {
   my ($self, $req, $page) = @_;

   return $self->tm->markdown( $page->{content}->all );
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
