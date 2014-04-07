package App::Doh::View::HTML::Markdown;

use namespace::sweep;

use Moo;
use Class::Usul::Types qw( ArrayRef Object );
use Scalar::Util       qw( blessed );
use Text::Markdown;

extends q(App::Doh);

has 'extensions' => is => 'lazy', isa => ArrayRef,
   builder       => sub { $_[ 0 ]->config->extensions->{markdown} };

has 'tm'         => is => 'lazy', isa => Object,
   builder       => sub { Text::Markdown->new( tab_width => 3 ) };

sub serialize {
   my ($self, $req, $page) = @_; my $content = $page->{content};

   my $markdown =  blessed $content ? $content->all : $content;
      $markdown =~ s{ \s+ \z }{}mx; $markdown .= "\n\n";

   return $page->{editing} ? $markdown : $self->tm->markdown( $markdown );
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
