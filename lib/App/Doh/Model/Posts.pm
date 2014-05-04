package App::Doh::Model::Posts;

use feature 'state';
use namespace::sweep;

use Moo;
use App::Doh::Functions    qw( build_navigation_list build_tree localise_tree
                               mtime );
use Class::Usul::Constants;
use Class::Usul::Functions qw( throw );
use File::DataClass::Types qw( Path Str );
use HTTP::Status           qw( HTTP_NOT_FOUND );

extends q(App::Doh::Model);
with    q(App::Doh::Role::CommonLinks);
with    q(App::Doh::Role::PageConfiguration);
with    q(App::Doh::Role::Preferences);

has 'root_mtime' => is => 'lazy', isa => Path, coerce => Path->coercion,
   builder       => sub { $_[ 0 ]->config->file_root->catfile( '.posts' ) };

with q(App::Doh::Role::PageLoading);

around 'load_page' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $page = $self->load_localised_page( $orig, $req, @args );

   # TODO: Set docs_url?
   $page->{wanted} //= join '/', 'posts', @{ $req->args };

   return $page;
};

sub localised_tree {
   return localise_tree $_[ 0 ]->posts, $_[ 1 ];
}

sub posts {
   my $self = shift; state $cache; my $filesys = $self->root_mtime;

   if (not defined $cache or $filesys->stat->{mtime} > $cache->{_mtime}) {
      my $max_mtime = 0;
      my $conf      = $self->config;
      my $no_index  = join '|', grep { not m{ posts }mx } @{ $conf->no_index };

      for my $locale (@{ $conf->locales }) {
         my $dir = $conf->file_root->catdir( $locale, 'posts' )
                        ->filter( sub { not m{ (?: $no_index ) }mx } );

         $dir->exists or next; my $lcache = $cache->{ $locale } //= {};

         $lcache->{tree} = build_tree( $self->type_map, $dir, 1, 0, 'posts' );
         $lcache->{type} = 'folder';

         my $mtime = mtime $lcache; $mtime > $max_mtime and $max_mtime = $mtime;
      }

      $filesys->touch( $cache->{_mtime} = $max_mtime );
   }

   return $cache;
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
