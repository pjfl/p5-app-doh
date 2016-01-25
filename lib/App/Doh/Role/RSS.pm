package App::Doh::Role::RSS;

use namespace::autoclean;

use App::Doh::Util         qw( iterator mtime );
use Class::Usul::Constants qw( EXCEPTION_CLASS NUL TRUE );
use Class::Usul::Functions qw( create_token throw );
use Class::Usul::Time      qw( time2str );
use Class::Usul::Types     qw( HashRef NonEmptySimpleStr
                               NonZeroPositiveInt Object Str );
use HTTP::Status           qw( HTTP_OK HTTP_NOT_FOUND );
use Moo::Role;

requires qw( base_uri config initialise_page localised_tree users );

has 'feed_domain'      => is => 'ro', isa => NonEmptySimpleStr,
   default             => 'http://localhost:5000';

has 'feed_subtitle'    => is => 'ro', isa => Str, default => NUL;

has 'feed_title'       => is => 'ro', isa => Str, default => NUL;

has 'formatters'       => is => 'ro', isa => HashRef[Object],
   builder             => sub { {} };

has 'max_feed_chars'   => is => 'ro', isa => NonZeroPositiveInt, default => 500;

has 'max_feed_entries' => is => 'ro', isa => NonZeroPositiveInt, default => 10;

has 'max_feed_lines'   => is => 'ro', isa => NonZeroPositiveInt, default => 5;

# Construction
around 'BUILDARGS' => sub {
   my ($orig, $self, @args) = @_; my $attr = $orig->( $self, @args );

   my $views = $attr->{views} or return $attr;

   exists $views->{html} and $attr->{formatters} = $views->{html}->formatters;

   return $attr;
};

# Private methods
my $_uri_base = sub {
   my ($self, $req) = @_; $req->mode ne 'static' and return;

   my $conf = $self->config; (my $mp = $conf->mount_point) =~ s{ \A / \z }{}mx;

   return $self->feed_domain."${mp}/".$conf->static.'/';
};

my $_filter_content = sub {
   my $self      = shift;
   my $max_chars = $self->max_feed_chars;
   my $max_lines = $self->max_feed_lines;

   return sub {
      my ($self, $src) = @_; my @lines = split m{ \n }mx, $src, $max_lines + 1;

      @lines > $max_lines and pop @lines;

      return (substr join( "\n", @lines), 0, $max_chars - 3).'...';
   }
};

my $_format_page = sub {
   my ($self, $req, $page, $uri_base) = @_;

   my $content = $page->{content}; my $formatter;

   $page->{format} and $formatter = $self->formatters->{ $page->{format} };

   $formatter and $page->{filter} = $_filter_content->( $self )
              and $content = $formatter->serialize( $req, $page );

   my $author = $page->{author} // $self->config->author;
   my $user   = $self->users->find( $author );
   my $email  = $user ? $user->email : "${author}\@example.com";

   return {
      author     => "${email} (${author})",
      categories => $page->{categories} // [],
      content    => $content,
      created    => time2str( '%Y-%m-%dT%XZ', $page->{created} ),
      guid       => substr( create_token( $page->{url} ), 0, 32 ),
      modified   => time2str( '%Y-%m-%dT%XZ', $page->{modified} ),
      link       => $req->uri_for( $page->{url}, { base => $uri_base } ),
      title      => $req->loc( $page->{title} ), };
};

# Public methods
sub get_rss_feed {
   my ($self, $req) = @_; my $locale = $req->locale;

   my $tree = $self->localised_tree( $locale ) or throw
      'Locale [_1] has no document tree', [ $locale ], rv => HTTP_NOT_FOUND;
   my $iter = iterator $tree;

   my @tuples; while (defined( my $node = $iter->() )) {
      $node->{type} eq 'file' and $node->{id} ne 'index'
         and push @tuples, [ $node->{modified}, $node ];
   }

   my @entries; my $uri_base = $self->$_uri_base( $req );

   for my $node (map { $_->[ 1 ] } sort { $b->[ 0 ] <=> $a->[ 0 ] } @tuples) {
      my $page = $self->initialise_page( $req, $node, $locale );

      push @entries, $self->$_format_page( $req, $page, $uri_base );
      @entries >= $self->max_feed_entries and last;
   }

  (my $lang = lc $locale) =~ s{ [_] }{-}mx;

   return {
      code        => HTTP_OK,
      page        => {
         built    => time2str( '%a, %d %b %Y %X %Z', mtime( $tree ), 'GMT' ),
         entries  => [ @entries ],
         language => $lang,
         link     => $self->base_uri( $req, { base => $uri_base } ),
         pubdate  => time2str( '%a, %d %b %Y %X %Z', time, 'GMT' ),
         subtitle => $req->loc( $self->feed_subtitle ),
         title    => $req->loc( $self->feed_title ), },
      view        => 'rss', };
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
