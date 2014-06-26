package App::Doh::Model::Documentation;

use feature 'state';

use Moo;
use App::Doh::Attributes;
use App::Doh::Functions    qw( build_tree iterator localise_tree mtime );
use Class::Usul::Functions qw( first_char io throw );
use HTTP::Status           qw( HTTP_NOT_FOUND );

extends q(App::Doh::Model);
with    q(App::Doh::Role::Authorization);
with    q(App::Doh::Role::CommonLinks);
with    q(App::Doh::Role::PageConfiguration);
with    q(App::Doh::Role::PageLoading);
with    q(App::Doh::Role::Preferences);
with    q(App::Doh::Role::Templates);
with    q(App::Doh::Role::Editor);

# Construction
around 'get_page' => sub {
   my ($orig, $self, $req, $node, $locale) = @_;

   my $page = $orig->( $self, $req, $node, $locale );

   $page->{docs_url} = $self->docs_url( $req, $locale );

   return $page;
};

around 'load_page' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $page = $orig->( $self, $req, @args );

   $page->{docs_url} //= $self->docs_url( $req );

   return $page;
};

# Public methods
sub create_file_action : Role(editor) {
   return shift->create_file( @_ );
}

sub dialog_action : Role(anon) {
   return shift->dialog( @_ );
}

sub delete_file_action : Role(editor) {
   my ($self, $req) = @_; my $res = $self->delete_file( $req );

   $res->{redirect}->{location} = $self->docs_url( $req );
   return $res;
}

sub docs_tree {
   my $self = shift; state $cache; my $filesys = $self->config->root_mtime;

   if (not defined $cache or $filesys->stat->{mtime} > $cache->{_mtime}) {
      my $conf     = $self->config;
      my $no_index = join '|', @{ $conf->no_index };
      my $root     = io( $conf->file_root );
      my $dir      = $root->filter( sub { not m{ (?: $no_index ) }mx } );

      $cache = build_tree( $self->type_map, $dir );
      $filesys->touch( $cache->{_mtime} );
   }

   return $cache;
}

sub docs_url {
   return $_[ 1 ]->uri_for( $_[ 0 ]->_docs_url( $_[ 2 ] // $_[ 1 ]->locale ) );
}

sub generate_static_action : Role(editor) {
   my ($self, $req) = @_; my $res = $self->generate_static( $req );

   $res->{redirect}->{location} = $self->docs_url( $req );
   return $res;
}

sub locales {
   return grep { first_char $_ ne '_' } keys %{ $_[ 0 ]->docs_tree };
}

sub localised_tree {
   return localise_tree $_[ 0 ]->docs_tree, $_[ 1 ];
}

sub rename_file_action : Role(editor) {
   return shift->rename_file( @_ );
}

sub save_file_action : Role(editor) {
   return shift->save_file( @_ );
}

sub search_document_action : Role(anon) {
   return shift->search_document( @_ );
}

sub upload_file_action : Role(editor) {
   my ($self, $req) = @_; my $res = $self->upload_file( $req );

   $res->{redirect}->{location} = $self->docs_url( $req );
   return $res;
}

# Private methods
sub _docs_url {
   my ($self, $locale) = @_; state $cache //= {};

   my $node  = $self->localised_tree( $locale )
      or throw error => 'No document tree for locale [_1]',
                args => [ $locale ], rv => HTTP_NOT_FOUND;
   my $mtime = mtime $node;
   my $tuple = $cache->{ $locale };

   (not $tuple or $mtime > $tuple->[ 0 ]) and $cache->{ $locale }
      = $tuple = [ $mtime, $self->_find_first_url( $locale ) ];

   return $tuple->[ 1 ];
}

sub _find_first_url {
   my ($self, $locale) = @_;

   my $iter = iterator( $self->localised_tree( $locale ) );

   while (defined (my $node = $iter->())) {
      $node->{type} ne 'folder' and $node->{id} ne 'index'
         and return $node->{url};
   }

   my $error = "Config Error: Unable to find the first page in\n"
      ."the /docs folder. Double check you have at least one file in the root\n"
      ."of the /docs folder. Also make sure you do not have any empty folders";

   $self->log->error( $error );
   return '/';
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
