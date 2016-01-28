package App::Doh::Model::Documentation;

use App::Doh::Attributes;  # Will do cleaning
use App::Doh::Util         qw( build_tree iterator localise_tree mtime );
use Class::Usul::Constants qw( NUL );
use Class::Usul::Functions qw( first_char throw );
use HTTP::Status           qw( HTTP_NOT_FOUND );
use Moo;

extends q(App::Doh::Model);
with    q(App::Doh::Role::PageConfiguration);
with    q(App::Doh::Role::PageLoading);
with    q(App::Doh::Role::Authorization);
with    q(App::Doh::Role::Editor);
with    q(App::Doh::Role::RSS);

has '+moniker' => default => 'docs';

# Construction
around 'initialise_page' => sub {
   my ($orig, $self, $req, $node, $locale) = @_;

   my $page = $orig->( $self, $req, $node, $locale );

   $page->{docs_url} = $self->docs_url( $req, $locale );

   return $page;
};

around 'initialise_stash' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $stash = $orig->( $self, $req, @args ); my $links = $stash->{links};

   $links->{rss_uri} = $req->uri_for( 'rss', { extension => '.xml' } );
   $links->{dialog } = $req->uri_for( 'dialog' );

   return $stash;
};

around 'load_page' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $page = $orig->( $self, $req, @args );

   $page->{docs_url} //= $self->docs_url( $req );

   return $page;
};

# Private package variables
my $_docs_tree_cache = { _mtime => 0, };
my $_docs_url_cache  = {};

# Private methods
my $_find_first_url = sub {
   my ($self, $tree) = @_; my $iter = iterator $tree;

   while (defined (my $node = $iter->())) {
      $node->{type} ne 'folder' and $node->{id} ne 'index'
         and return $node->{url};
   }

   my $error = 'Config Error: Unable to find the first page in the /docs '
             . 'folder. Double check you have at least one file in the root '
             . 'of the /docs folder. Also make sure you do not have any empty '
             . 'folders';

   $self->log->error( $error );
   return '/';
};

my $_docs_url = sub {
   my ($self, $locale) = @_;

   my $tree  = $self->localised_tree( $locale )
      or throw 'Locale [_1] has no document tree', [ $locale ],
         rv => HTTP_NOT_FOUND;
   my $tuple = $_docs_url_cache->{ $locale };
   my $mtime = mtime $tree;

   (not $tuple or $mtime > $tuple->[ 0 ]) and $_docs_url_cache->{ $locale }
      = $tuple = [ $mtime, $self->$_find_first_url( $tree ) ];

   return $tuple->[ 1 ];
};

# Public methods
sub base_uri {
   return $_[ 1 ]->uri_for( NUL, $_[ 2 ] );
}

sub create_file_action : Role(editor) {
   return shift->create_file( @_ );
}

sub delete_file_action : Role(editor) {
   my ($self, $req) = @_; my $res = $self->delete_file( $req );

   $res->{redirect}->{location} = $self->docs_url( $req );
   return $res;
}

sub docs_url {
   return $_[ 1 ]->uri_for( $_[ 0 ]->$_docs_url( $_[ 2 ] // $_[ 1 ]->locale ) );
}

sub dialog : Role(any) {
   return shift->get_dialog( @_ );
}

sub index : Role(anon) {
   return shift->get_content( @_ );
}

sub locales {
   return grep { first_char $_ ne '_' } keys %{ $_[ 0 ]->tree_root };
}

sub localised_tree {
   return localise_tree $_[ 0 ]->tree_root, $_[ 1 ];
}

sub make_draft {
   my ($self, @pathname) = @_; return $self->config->drafts, @pathname;
}

sub rename_file_action : Role(editor) {
   return shift->rename_file( @_ );
}

sub rename_file_path_fix {
   return $_[ 1 ];
}

sub rss_feed : Role(anon) {
   return shift->get_rss_feed( @_ );
}

sub save_file_action : Role(editor) {
   return shift->save_file( @_ );
}

sub search : Role(any) {
   return shift->search_files( @_ );
}

sub tree_root {
   my $self = shift; my $conf = $self->config; my $filesys = $conf->root_mtime;

   my $mtime = $filesys->exists ? $filesys->stat->{mtime} // 0 : 0;

   if ($mtime == 0 or $mtime > $_docs_tree_cache->{_mtime}) {
      my $no_index = join '|', @{ $conf->no_index };
      my $filter   = sub { not m{ (?: $no_index ) }mx };
      my $dir      = $conf->file_root->clone->filter( $filter );

      $_docs_tree_cache = build_tree( $self->type_map, $dir );
      $filesys->touch( $_docs_tree_cache->{_mtime} );
   }

   return $_docs_tree_cache;
}

sub upload : Role(editor) {
   my ($self, $req) = @_; my $res = $self->upload_file( $req );

   $res->{redirect}->{location} = $self->docs_url( $req );

   return $res;
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
