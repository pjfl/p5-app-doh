package App::Doh::View::HTML::Markdown;

use namespace::autoclean;

use App::Doh::Markdown;
use Class::Usul::Types qw( ArrayRef Object );
use Scalar::Util       qw( blessed );
use Moo;

with q(Web::Components::Role);

# Public attributes
has '+moniker'   => default => 'markdown';

has 'extensions' => is => 'lazy', isa => ArrayRef,
   builder       => sub { $_[ 0 ]->config->extensions->{markdown} };

has 'formatter'  => is => 'lazy', isa => Object, builder => sub {
   App::Doh::Markdown->new( tab_width => $_[ 0 ]->config->mdn_tab_width ) };

# Public methods
sub serialize {
   my ($self, $req, $page) = @_; my $content = $page->{content};

   my $markdown = blessed $content ? $content->all : $content;

   $page->{editing} and return $markdown;

   $markdown =~ s{ \A --- $ ( .* ) ^ --- $ }{}msx;

   $page->{filter} and $markdown = $page->{filter}->( $self, $markdown );

   return $self->formatter->markdown( $markdown );
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
