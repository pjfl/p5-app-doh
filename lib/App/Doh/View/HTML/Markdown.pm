package App::Doh::View::HTML::Markdown;

use namespace::sweep;

use App::Doh::Markdown;
use Class::Usul::Types qw( ArrayRef Object );
use Scalar::Util       qw( blessed );
use YAML::Tiny;
use Moo;

extends q(App::Doh);

has 'extensions' => is => 'lazy', isa => ArrayRef,
   builder       => sub { $_[ 0 ]->config->extensions->{markdown} };

has 'tm'         => is => 'lazy', isa => Object, builder => sub {
   App::Doh::Markdown->new( tab_width => $_[ 0 ]->config->mdn_tab_width ) };

has 'yt'         => is => 'lazy', isa => Object,
   builder       => sub { YAML::Tiny->new };

sub serialize {
   my ($self, $req, $page) = @_; my $content = $page->{content};

   my $markdown = blessed $content ? $content->all : $content;

   my $yaml; $markdown =~ s{ \A --- $ ( .* ) ^ --- $ }{}msx and $yaml = $1;

   if ($yaml) {
      my $data = $self->yt->read_string( $yaml )->[ 0 ];

      $page->{ $_ } = $data->{ $_ } for (keys %{ $data });
   }

   return $page->{editing} ? $markdown : $self->tm->markdown( $markdown );
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
