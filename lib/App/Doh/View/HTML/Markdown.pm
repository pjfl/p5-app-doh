package App::Doh::View::HTML::Markdown;

use namespace::autoclean;

use App::Doh::Markdown;
use Class::Usul::Time  qw( str2time );
use Class::Usul::Types qw( ArrayRef Object );
use Scalar::Util       qw( blessed );
use YAML::Tiny;
use Moo;

with q(Web::Components::Role);

# Public attributes
has '+moniker'   => default => 'markdown';

has 'extensions' => is => 'lazy', isa => ArrayRef,
   builder       => sub { $_[ 0 ]->config->extensions->{markdown} };

has 'tm'         => is => 'lazy', isa => Object, builder => sub {
   App::Doh::Markdown->new( tab_width => $_[ 0 ]->config->mdn_tab_width ) };

has 'yt'         => is => 'lazy', isa => Object,
   builder       => sub { YAML::Tiny->new };

# Public methods
sub serialize {
   my ($self, $req, $page) = @_; my $content = $page->{content};

   my $markdown = blessed $content ? $content->all : $content;

   $page->{editing} and return $markdown;

   my $yaml; $markdown =~ s{ \A --- $ ( .* ) ^ --- $ }{}msx and $yaml = $1;

   if ($yaml) {
      my $data = $self->yt->read_string( $yaml )->[ 0 ];

      exists $data->{created} and $data->{created} = str2time $data->{created};

      $page->{ $_ } = $data->{ $_ } for (keys %{ $data });
   }

   $page->{filter} and $markdown = $page->{filter}->( $self, $markdown );

   return $self->tm->markdown( $markdown );
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
