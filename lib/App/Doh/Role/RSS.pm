package App::Doh::Role::RSS;

use namespace::autoclean;

use App::Doh::Util         qw( iterator );
use Class::Usul::Constants qw( EXCEPTION_CLASS NUL );
use Class::Usul::Functions qw( throw );
use Class::Usul::Types     qw( NonZeroPositiveInt Str );
use HTTP::Status           qw( HTTP_OK HTTP_NOT_FOUND );
use Moo::Role;

requires qw( base_uri config initialise_page localised_tree );

has 'feed_subtitle'   => is => 'ro', isa => Str, default => NUL;

has 'feed_title'      => is => 'ro', isa => Str, default => NUL;

has 'max_rss_entries' => is => 'ro', isa => NonZeroPositiveInt, default => 10;

# Public methods
sub get_rss_feed {
   my ($self, $req) = @_;

   my $conf   = $self->config;
   my $locale = $conf->locale; # Always index config default language
   my $tree   = $self->localised_tree( $locale )
      or  throw 'Default locale [_1] has no document tree', [ $locale ],
                rv => HTTP_NOT_FOUND;
   my $iter   = iterator $tree;
   my @tuples;

   while (defined( my $node = $iter->() )) {
      $node->{type} eq 'file' and $node->{id} ne 'index'
         and push @tuples, [ $node->{date}, $node ];
   }

   my @entries;

   for my $node (map { $_->[ 1 ] } sort { $b->[ 0 ] <=> $a->[ 0 ] } @tuples) {
      push @entries, $self->initialise_page( $req, $node, $conf->locale );
      @entries >= $self->max_rss_entries and last;
   }

   return { code => HTTP_OK,
            page => { entries  => [ @entries ],
                      link     => $self->base_uri( $req ),
                      subtitle => $req->loc( $self->feed_subtitle ),
                      title    => $req->loc( $self->feed_title ), },
            view => 'rss', };
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
