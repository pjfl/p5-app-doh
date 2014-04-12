package App::Doh::Model::Documentation;

use 5.010001;
use namespace::sweep;

use Moo;
use Class::Usul::Constants;
use Class::Usul::Functions qw( throw );
use File::DataClass::IO;
use File::DataClass::Types qw( HashRef Int Path Str );
use Unexpected::Functions  qw( Unspecified );

extends q(App::Doh::Model);
with    q(App::Doh::Role::CommonLinks);
with    q(App::Doh::Role::PageConfiguration);
with    q(App::Doh::Role::Preferences);

# Public attributes
has 'no_index'   => is => 'lazy', isa => Str,
   builder       => sub { join '|', @{ $_[ 0 ]->config->no_index } };

has 'root_mtime' => is => 'lazy', isa => Path, coerce => Path->coercion,
   builder       => sub { $_[ 0 ]->config->file_root->catfile( '.mtime' ) };

has 'type_map'   => is => 'lazy', isa => HashRef, builder => sub { {} };

# Public methods
sub content_from_file {
   my ($self, $req) = @_; my $ids = $req->{args};

   my $stash = $self->get_stash( $req, $self->load_page( $req ) );

   $stash->{nav     } = $self->navigation( $req );
   $stash->{template} = defined $ids->[ 0 ] && $ids->[ 0 ] ne 'index'
                      ? 'documentation' : undef;

   return $stash;
}

sub create_file {
   my ($self, $req) = @_;

   $req->username ne 'unknown' or throw 'File creation not authorised';

   my $node     = $self->_get_file_meta( $req );
   my $content  = $req->loc( $self->config->default_content );
   my $path     = $node->{path};

   $path->assert_filepath->println( $content )->close;
   $self->root_mtime->touch( $path->stat->{mtime} );

   my $location = $req->uri_for( $node->{url} );
   my $rel_path = $path->abs2rel( $self->config->file_root );
   my $message  = [ 'File [_1] created by [_2]', $rel_path, $req->username ];

   return { redirect => { location => $location, message => $message } };
}

sub create_file_form {
   my ($self, $req) = @_;

   my $page  = {
      literal_js => [ "var form = document.forms[ 'create-file' ];",
                      "var f    = function() { form.pathname.focus() };",
                      "f.delay( 100 );" ],
      meta       => { id => __get_or_throw( $req->params, 'id' ) }, };
   my $stash = $self->get_stash( $req, $page );

   $stash->{template} = 'create-file';
   return $stash;
}

sub docs_tree {
   my $self = shift; state $tree //= $self->_build_docs_tree;

   $self->root_mtime->stat->{mtime} > $tree->{_mtime}
      and $tree = $self->_build_docs_tree;

   return $tree;
}

sub file_delete {
   my ($self, $req) = @_;

   $req->username ne 'unknown' or throw 'Delete not authorised';

   my $node     = $self->_find_node( $req, [ @{ $req->args } ] )
      or throw 'Cannot find document tree node to delete';
   my $path     = $node->{path}; $path->unlink; $self->root_mtime->touch;
   my $rel_path = $path->abs2rel( $self->config->file_root );
   my $message  = [ 'File [_1] deleted by [_2]', $rel_path, $req->username ];

   # TODO: Make the message visible on the index page
   return { redirect => { location => $req->base, message => $message } };
}

sub file_save {
   my ($self, $req) = @_;

   $req->username ne 'unknown' or throw 'Update not authorised';

   my $node     =  $self->_find_node( $req, [ @{ $req->args } ] )
      or throw 'Cannot find document tree node to update';
   my $content  =  $req->body->param->{content};
      $content  =~ s{ \r\n }{\n}gmx; $content =~ s{ \s+ \z }{}mx;
   my $path     =  $node->{path}; $path->println( $content ); $path->close;
   my $rel_path =  $path->abs2rel( $self->config->file_root );
   my $message  =  [ 'File [_1] updated by [_2]', $rel_path, $req->username ];

   $node->{mtime} = $path->stat->{mtime};

   return { redirect => { location => $req->uri, message => $message } };
}

sub iterator {
   my ($self, $locale) = @_; my $node = $self->_localised_tree( $locale );

   my @folders = $node && $node->{type} eq 'folder' ? ( $node ) : ();

   return sub {
      while (@folders) {
         while (defined ($node = __current( $folders[ 0 ]->{tree} ))) {
            $node->{type} eq 'folder' and push @folders, $node;
            __next( $folders[ 0 ]->{tree} );
            return $node;
         }

         shift @folders;
      }

      return $node;
   };
}

sub load_page {
   my ($self, $req) = @_;

   my $node = $self->_find_node( $req, [ @{ $req->args } ] );
   my $tree = $self->_localised_tree( $req->locale )->{tree};
   my $url  = $req->uri_for( $self->_docs_url( $req->locale ) );
   my $home = exists $tree->{index} ? $req->uri_for( NUL ) : $url;

   $node and $node->{type} eq 'file' and return {
      content      => $node->{path},
      docs_url     => $url,
      editing      => $req->params->{edit} // FALSE,
      format       => $node->{format},
      header       => $node->{title},
      homepage_url => $home,
      mode         => $req->params->{mode} // 'online',
      mtime        => $node->{mtime},
      title        => ucfirst $node->{name}, };

   my $title   = $req->loc( 'Not found' );
   my $content = '> '.$req->loc( "Oh no. That page doesn't exist" )
                 ."\n\n    Code 404\n\n";

   return { content      => $content,
            docs_url     => $url,
            editing      => FALSE,
            format       => 'markdown',
            header       => $title,
            homepage_url => $home,
            mtime        => time,
            title        => $title, };
}

sub navigation {
   my ($self, $req) = @_; my $ids = [ @{ $req->args } ];

   my $tree = $self->_localised_tree( $req->locale )->{tree};

   return __build_nav_list( $tree, $ids, (join '/', @{ $ids }), 0 );
}

sub rename_file {
   my ($self, $req) = @_;

   $req->username ne 'unknown' or throw 'File creation not authorised';

   my $node     = $self->_find_node( $req, [ @{ $req->args } ] )
      or throw 'Cannot find document tree node to rename';
   my $new_node = $self->_get_file_meta( $req );

   $node->{path}->move( $new_node->{path} ); $self->root_mtime->touch;

   my $location = $req->uri_for( $new_node->{url} );
   my $rel_path = $node->{path}->abs2rel( $self->config->file_root );
   my $message  = [ 'File [_1] renamed by [_2]', $rel_path, $req->username ];

   return { redirect => { location => $location, message => $message } };
}

sub rename_file_form {
   my ($self, $req) = @_;

   my $page  = {
      literal_js => [ "var form = document.forms[ 'rename-file' ];",
                      "var f    = function() { form.pathname.focus() };",
                      "f.delay( 100 );" ],
      meta       => { id => __get_or_throw( $req->params, 'id' ) }, };
   my $stash = $self->get_stash( $req, $page );

   $stash->{template} = 'rename-file';
   return $stash;
}

# Private methods
sub _build_docs_tree {
   my ($self, $dir, $level, $url_base, $title) = @_; my $tree = {};

   my $max_mtime = 0; my $no_index = $self->no_index; state $order //= 0;

   $dir //= $self->config->file_root; $level //= 0; $level++;

   $url_base //= NUL; $title //= NUL;

   for my $path ($dir->filter( sub { not m{ (?: $no_index ) }mx } )->all) {
      my $id         =  __make_id_from  ( $path->filename );
      my $name       =  __make_name_from( $id );
      my $url        =  $url_base ? "${url_base}/${id}"  : $id;
      my $full_title =  $title    ? "${title} - ${name}" : $name;
      my $mtime      =  $path->stat->{mtime};
      my $node       =  $tree->{ $id } = {
         format      => $self->_get_format( $path->pathname ),
         id          => $id,
         level       => $level,
         mtime       => $mtime,
         name        => $name,
         path        => $path->utf8,
         title       => $full_title,
         type        => 'file',
         url         => $url,
         _order      => $order++, };

      $path->is_file and $mtime > $max_mtime and $max_mtime = $mtime;
      $path->is_dir or next;
      $node->{type} = 'folder';
      $node->{tree} = $level > 1 # Skip the language code directories
                    ? $self->_build_docs_tree( $path, $level, $url, $name )
                    : $self->_build_docs_tree( $path, $level, NUL,  NUL   );
      $node->{tree}->{_mtime} > $max_mtime
         and $max_mtime = $node->{tree}->{_mtime};
   }

   $level == 1 and $self->root_mtime->touch( $max_mtime );
   $tree->{_mtime} = $max_mtime;
   return $tree;
}

sub _docs_url {
   my ($self, $locale) = @_; my $lang = __extract_lang( $locale );

   state $urls //= {}; defined $urls->{ $lang } and return $urls->{ $lang };

   my $iter = $self->iterator( $locale );

   while (defined (my $node = $iter->())) {
      $node->{type} eq 'file' and $node->{id} ne 'index'
         and return $urls->{ $lang } = $node->{url};
   }

   my $error = "Config Error: Unable to find the first page in\n"
      ."the /docs folder. Double check you have at least one file in the root\n"
      ."of the /docs folder. Also make sure you do not have any empty folders";

   $self->log->fatal( $error );
   return '/';
}

sub _find_node {
   my ($self, $req, $ids) = @_;

   $ids //= []; $ids->[ 0 ] or $ids->[ 0 ] = 'index';

   my $tree = $self->_localised_tree( $req->locale );

   for my $node_id (map { $_ ? $_ : 'index' } @{ $ids }) {
      $tree->{type} eq 'folder' and $tree = $tree->{tree};
      exists  $tree->{ $node_id } or return FALSE;
      $tree = $tree->{ $node_id };
   }

   return $tree;
}

sub _get_file_meta {
   my ($self, $req) = @_;

   my $pathname =  $req->body->param->{pathname};
      $pathname !~ m{ \. [m][k]?[d][n]? \z }mx and $pathname .= '.md';
   my @filepath =  map { __make_id_from( $_ ) }
   my @pathname =  split m{ / }mx, $pathname;
   my $id       =  pop @filepath;
   my $url      =  join '/', @filepath, $id;
   my $parent   =  $self->_find_node( $req, [ @filepath ] );
   my $lang     = (split m{ _ }mx, $req->locale)[ 0 ];
   my $path     =  $self->config->file_root->catfile( $lang, @pathname )->utf8;

   ($parent and $parent->{type} eq 'folder')
       or throw error => 'Parent folder [_1] does not exist',
                 args => [ join '/', $lang, @pathname ];

   exists $parent->{tree}->{ $id }
      and throw error => 'Path [_1] already exists',
                 args => [ join '/', $lang, @pathname ];

   return { path => $path, url => $url, };
}

sub _get_format {
   my ($self, $path) = @_; my $extn = (split m{ \. }mx, $path)[ -1 ] || NUL;

   return $self->type_map->{ $extn } || 'text';
}

sub _localised_tree {
   my ($self, $locale) = @_;

   my $lang = __extract_lang( $locale ); my $tree = $self->docs_tree;

   $lang and defined $tree->{ $lang } and return $tree->{ $lang };
   $lang = __extract_lang( $self->config->locale );
   $lang and defined $tree->{ $lang } and return $tree->{ $lang };

   return $tree->{ LANG };
}

# Private functions
sub __build_nav_list {
   my ($tree, $ids, $wanted, $level) = @_; my @nav = ();

   for my $node (map  { $tree->{ $_ } }
                 grep { $_ ne 'index' } __sorted_keys( $tree )) {
      my $page = { level => $level,
                   name  => $node->{name},
                   type  => $node->{type},
                   url   => $node->{type} eq 'folder' ? '#' : $node->{url}, };

      if (defined $ids->[ 0 ] and $ids->[ 0 ] eq $node->{id}) {
         $page->{class} = $node->{url} eq $wanted ? 'active' : 'open';
         shift @{ $ids };
      }

      push @nav, $page;

      $node->{type} eq 'folder' and push @nav, @{
         __build_nav_list( $node->{tree}, $ids, $wanted, $level + 1 ) };
   }

   return \@nav;
}

sub __current {
   my $href = shift;

   exists $href->{_iterator}
       or $href->{_iterator} = [ 0, __sorted_keys( $href ) ];

   my $key = $href->{_iterator}->[ $href->{_iterator}->[ 0 ] + 1 ] or return;

   return $href->{ $key };
}

sub __extract_lang {
   my $locale = shift; return $locale ? (split m{ _ }mx, $locale)[ 0 ] : LANG;
}

sub __get_or_throw {
   my ($params, $name) = @_;

   defined (my $param = $params->{ $name })
      or throw class => Unspecified, args => [ $name ];

   return $param;
}

sub __make_id_from {
   my $text = shift;

   $text =~ s{ \A \d+ [_] }{}mx; $text =~ s{ \. [a-zA-Z0-9_\+]+ \z }{}mx;

   return $text;
}

sub __make_name_from {
   my $text = shift; $text =~ s{ [_] }{ }gmx; return $text;
}

sub __next {
   my $href = shift; __current( $href ); $href->{_iterator}->[ 0 ] += 1;

   return __current( $href );
}

sub __sorted_keys {
   my $href = shift;

   return ( sort { $href->{ $a }->{_order} cmp $href->{ $b }->{_order} }
            grep { '_' ne substr $_, 0, 1 } keys %{ $href } );
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
