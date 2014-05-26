package App::Doh::Model::Posts;

use feature 'state';
use namespace::sweep;

use Moo;
use App::Doh::Functions    qw( build_tree localise_tree mtime );
use Class::Usul::Constants qw( TRUE );
use Class::Usul::Functions qw( throw );
use File::DataClass::Types qw( Path Str );
use HTTP::Status           qw( HTTP_NOT_FOUND );

extends q(App::Doh::Model);
with    q(App::Doh::Role::CommonLinks);
with    q(App::Doh::Role::PageConfiguration);
with    q(App::Doh::Role::PageLoading);
with    q(App::Doh::Role::Preferences);

# Construction
around 'load_page' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $page = $orig->( $self, $req, @args );

   $page->{template    } //= 'posts';
   $page->{wanted      }   = join '/', $self->config->posts, @{ $req->args };
   $page->{wanted_depth}   = () = @{ $req->args };
   return $page;
};

around 'make_page' => sub {
   my ($orig, $self, @args) = @_; my $page = $orig->( $self, @args );

   $page->{type} eq 'folder' and $page->{template} = 'posts-index';

   return $page;
};

# Public methods
sub localised_tree {
   return localise_tree $_[ 0 ]->posts, $_[ 1 ];
}

sub posts {
   my $self = shift; state $cache; my $filesys = $self->config->root_mtime;

   if (not defined $cache or $filesys->stat->{mtime} > $cache->{_mtime}) {
      my $max_mtime = defined $cache->{_mtime} ? $cache->{_mtime} : 0;
      my $conf      = $self->config;
      my $postd     = $conf->posts;
      my $no_index  = join '|', grep { not m{ $postd }mx } @{ $conf->no_index };

      for my $locale (@{ $conf->locales }) {
         my $dir = $conf->file_root
                        ->catdir( $locale, $postd, { reverse => TRUE } )
                        ->filter( sub { not m{ (?: $no_index ) }mx } );

         $dir->exists or next; my $lcache = $cache->{ $locale } //= {};

         $lcache->{tree} = build_tree( $self->type_map, $dir, 1, 0, $postd );
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
