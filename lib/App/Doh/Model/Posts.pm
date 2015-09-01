package App::Doh::Model::Posts;

use App::Doh::Attributes;  # Will do cleaning
use App::Doh::Util         qw( build_tree iterator localise_tree mtime );
use Class::Usul::Constants qw( TRUE );
use Moo;

extends q(App::Doh::Model);
with    q(App::Doh::Role::PageConfiguration);
with    q(App::Doh::Role::Authorization);
with    q(App::Doh::Role::PageLoading);
with    q(App::Doh::Role::Editor);

has '+moniker' => default => 'posts';

# Private package variables
my $_posts_tree_cache = { _mtime => 0, };

# Private methods
my $_chain_nodes = sub {
   my ($self, $tree) = @_; my $iter = iterator $tree; my $prev;

   while (defined (my $node = $iter->())) {
      ($node->{type} eq 'folder' or $node->{id} eq 'index') and next;
      $prev and $prev->{next} = $node; $node->{prev} = $prev; $prev = $node;
   }

   return;
};

# Construction
around 'load_page' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $page = $orig->( $self, $req, @args );
   my @ids  = @{ $req->uri_params->() // [] };

   $ids[ 0 ] and $ids[ 0 ] eq 'index' and @ids = ();

   $page->{type} eq 'folder' and $page->{author} = $self->config->author;

   $page->{template    } =
      [ 'posts', $page->{type} eq 'folder' ? 'posts-index' : 'posts' ];
   $page->{wanted      } = join '/', $self->config->posts, @ids;
   $page->{wanted_depth} = () = @ids;
   return $page;
};

# Public methods
sub create_file_action : Role(editor) {
   return shift->create_file( @_ );
}

sub delete_file_action : Role(editor) {
   my ($self, $req) = @_; my $res = $self->delete_file( $req );

   $res->{redirect}->{location} = $req->uri_for( $self->config->posts );
   return $res;
}

sub localised_tree {
   return localise_tree $_[ 0 ]->posts, $_[ 1 ];
}

sub posts {
   my $self = shift; my $filesys = $self->config->root_mtime;

   if (not $filesys->exists
       or  $filesys->stat->{mtime} > $_posts_tree_cache->{_mtime}) {
      my $max_mtime = $_posts_tree_cache->{_mtime};
      my $conf      = $self->config;
      my $postd     = $conf->posts;
      my $no_index  = join '|', grep { not m{ $postd }mx } @{ $conf->no_index };

      for my $locale (@{ $conf->locales }) {
         my $dir = $conf->file_root
                        ->catdir( $locale, $postd, { reverse => TRUE } )
                        ->filter( sub { not m{ (?: $no_index ) }mx } );

         $dir->exists or next;

         my $lcache = $_posts_tree_cache->{ $locale } //= {};

         $lcache->{tree} = build_tree( $self->type_map, $dir, 1, 0, $postd );
         $lcache->{type} = 'folder';
         $self->$_chain_nodes( $lcache );

         my $mtime = mtime $lcache; $mtime > $max_mtime and $max_mtime = $mtime;
      }

      $filesys->touch( $_posts_tree_cache->{_mtime} = $max_mtime );
   }

   return $_posts_tree_cache;
}

sub rename_file_action : Role(editor) {
   return shift->rename_file( @_ );
}

sub save_file_action : Role(editor) {
   return shift->save_file( @_ );
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
