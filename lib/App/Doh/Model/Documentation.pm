package App::Doh::Model::Documentation;

use 5.010001;
use namespace::sweep;

use Moo;
use Class::Usul::Constants;
use Class::Usul::Functions qw( first_char throw trim );
use Class::Usul::IPC;
use File::DataClass::IO;
use File::DataClass::Types qw( HashRef Int Object Path Str );
use HTTP::Status           qw( HTTP_EXPECTATION_FAILED HTTP_NOT_FOUND );
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

has 'ipc'        => is => 'lazy', isa => Object,
   builder       => sub { Class::Usul::IPC->new( builder => $_[ 0 ]->usul ) };

# Construction
around 'load_page' => sub {
   my ($orig, $self, $req, @args) = @_; my $conf = $self->config;

   $args[ 0 ] and return $orig->( $self, $req, $args[ 0 ] );

   for my $locale ($req->locale, $conf->locale) {
      my $node = $self->_find_node( $locale, [ @{ $req->args } ] );

      ($node and $node->{type} eq 'file') or next;

      return $orig->( $self, $req, $self->_make_page( $req, $locale, $node ) );
   }

   return $orig->( $self, $req, $self->_not_found( $req ) );
};

# Public methods
sub content_from_file {
   my ($self, $req) = @_; my $ids = $req->{args};

   my $stash = $self->get_stash( $req, $self->load_page( $req ) );

   $stash->{nav     } = $self->navigation( $req );
   $stash->{template} = defined $ids->[ 0 ] && $ids->[ 0 ] ne 'index'
                      ? 'documentation' : undef;

   return $stash;
}

sub create_file_action {
   my ($self, $req) = @_;

   $req->username ne 'unknown' or throw 'File creation not authorised';

   my $content  = $req->loc( $self->config->default_content );
   my $new_node = $self->_new_node( $req->locale, $req->body->param );
   my $path     = $new_node->{path};

   $path->assert_filepath->println( $content )->close;
   $self->_invalidate_cache( $path->stat->{mtime} );

   my $location = $req->uri_for( $new_node->{url} );
   my $rel_path = $path->abs2rel( $self->config->file_root );
   my $message  = [ 'File [_1] created by [_2]', $rel_path, $req->username ];

   return { redirect => { location => $location, message => $message } };
}

sub dialog {
   my ($self, $req) = @_;

   my $name = __get_or_throw( $req->params, 'name' );
   my $page = { meta => { id => __get_or_throw( $req->params, 'id' ) } };

   if    ($name eq 'create') {
      $page->{literal_js} = __set_element_focus( "${name}-file", 'pathname' );
   }
   elsif ($name eq 'rename') {
      $page->{literal_js} = __set_element_focus( "${name}-file", 'pathname' );
      $page->{old_path  } = __get_or_throw( $req->params, 'val' );
   }
   elsif ($name eq 'search') {
      $page->{literal_js} = __set_element_focus( "${name}-file", 'query' );
   }
   elsif ($name eq 'upload') {
      $page->{literal_js} = __copy_element_value();
   }

   my $stash = $self->get_stash( $req, $page );

   $stash->{template} = "${name}-file";
   return $stash;
}

sub delete_file_action {
   my ($self, $req) = @_;

   $req->username ne 'unknown' or throw 'Delete not authorised';

   my $node     = $self->_find_node( $req->locale, [ @{ $req->args } ] )
      or throw 'Cannot find document tree node to delete';
   my $rel_path = $self->_delete_and_prune( $node->{path} );
   my $location = $req->uri_for( $self->_docs_url( $req->locale ) );
   my $message  = [ 'File [_1] deleted by [_2]', $rel_path, $req->username ];

   return { redirect => { location => $location, message => $message } };
}

sub docs_tree {
   my $self = shift; state $cache //= $self->_build_docs_tree;

   $self->root_mtime->stat->{mtime} > $cache->{_mtime}
      and $cache = $self->_build_docs_tree;

   return $cache;
}

sub iterator {
   my ($self, $locale) = @_;

   my @folders = ( __make_tuple( $self->_localised_tree( $locale ) ) );

   return sub {
      while (my $tuple = $folders[ 0 ]) {
         while (defined (my $k = $tuple->[ 1 ]->[ $tuple->[ 0 ]++ ])) {
            my $node = $tuple->[ 2 ]->{tree}->{ $k };

            $node->{type} eq 'folder'
               and unshift @folders, __make_tuple( $node );

            return $node;
         }

         shift @folders;
      }

      return;
   };
}

sub locales {
   return grep { first_char $_ ne '_' } keys %{ $_[ 0 ]->docs_tree };
}

{  my $cache //= {};

   sub _invalidate_cache {
      my ($self, $mtime) = @_; $cache = {};

      $self->root_mtime->touch( $mtime );
      return;
   }

   sub navigation {
      my ($self, $req) = @_;

      my $locale = $self->config->locale; # Always index config default language
      my $mtime  = $self->_localised_tree( $locale )->{tree}->{_mtime};
      my $wanted = join '/', my @ids = @{ $req->args };
      my $list   = $cache->{ $wanted };

      (not $list or $mtime > $list->{mtime})
         and $cache->{ $wanted } = $list
            = { items => $self->_build_nav_list( $locale, \@ids, $wanted ),
                mtime => $mtime, };

      return $list->{items};
   }
}

sub rename_file_action {
   my ($self, $req) = @_;

   $req->username ne 'unknown' or throw 'File creation not authorised';

   my $param    = $req->body->param;
   my $old_path = [ split m{ / }mx, __get_or_throw( $param, 'old_path' ) ];
   my $node     = $self->_find_node( $req->locale, $old_path )
      or throw 'Cannot find document tree node to rename';
   my $new_node = $self->_new_node( $req->locale, $param );

   $new_node->{path}->assert_filepath;
   $node->{path}->close->move( $new_node->{path} ); __prune( $node->{path} );
   $self->_invalidate_cache;

   my $location = $req->uri_for( $new_node->{url} );
   my $rel_path = $node->{path}->abs2rel( $self->config->file_root );
   my $message  = [ 'File [_1] renamed by [_2]', $rel_path, $req->username ];

   return { redirect => { location => $location, message => $message } };
}

sub save_file_action {
   my ($self, $req) = @_;

   $req->username ne 'unknown' or throw 'Update not authorised';

   my $node     =  $self->_find_node( $req->locale, [ @{ $req->args } ] )
      or throw 'Cannot find document tree node to update';
   my $content  =  __defined_or_throw( $req->body->param, 'content' );
      $content  =~ s{ \r\n }{\n}gmx; $content =~ s{ \s+ \z }{}mx;
   my $path     =  $node->{path}; $path->println( $content ); $path->close;
   my $rel_path =  $path->abs2rel( $self->config->file_root );
   my $message  =  [ 'File [_1] updated by [_2]', $rel_path, $req->username ];

   $node->{mtime} = $path->stat->{mtime};

   return { redirect => { location => $req->uri, message => $message } };
}

sub search_file_action {
   my ($self, $req) = @_;

   my $root   = $self->config->file_root;
   # TODO: Sanitize user input
   my $query  = __get_or_throw( $req->params, 'query' );
   my $langd  = $root->catdir( __extract_lang( $req->locale ) );
   my $res    = $self->ipc->run_cmd( [ 'ack', $query, $langd->pathname ] );
   my $page   = $self->_search_results( $req, $langd, $res->stdout );
   my $stash  = $self->get_stash( $req, $self->load_page( $req, $page ) );

   $stash->{nav     } = $self->navigation( $req );
   $stash->{template} = 'documentation';
   return $stash;
}

sub upload_file {
   my ($self, $req) = @_; my $conf = $self->config;

   my $upload = $req->args->[ 0 ] or throw 'No upload object';

   $req->username ne 'unknown' or throw 'Update not authorised';

   $upload and not $upload->is_upload and throw $upload->reason;
   $upload->size > $conf->max_asset_size
      and throw error => 'File [_1] size [_2] too big',
                 args => [ $upload->filename, $upload->size ];

   my $path = $conf->assetdir->catfile( $upload->filename );

   io( $upload->path )->copy( $path->assert_filepath );

   my $rel_path = $path->abs2rel( $self->config->assetdir );
   my $location = $req->uri_for( $self->_docs_url( $req->locale ) );
   my $message  = [ 'File [_1] uploaded by [_2]', $rel_path, $req->username ];

   return { redirect => { location => $location, message => $message } };
}

# Private methods
sub _build_docs_tree {
   my ($self, $dir, $level, $order, $url_base, $title) = @_;

   my $max_mtime = 0; my $no_index = $self->no_index; my $tree = {};

   $dir //= $self->config->file_root; $level //= 0; $level++;

   $order //= 0; $url_base //= NUL; $title //= NUL;

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
                ? $self->_build_docs_tree( $path, $level, $order, $url, $name )
                : $self->_build_docs_tree( $path, $level, $order, NUL,  NUL   );
      $node->{tree}->{_mtime} > $max_mtime
         and $max_mtime = $node->{tree}->{_mtime};
   }

   $level == 1 and $self->root_mtime->touch( $max_mtime );
   $tree->{_mtime} = $max_mtime;
   return $tree;
}

sub _build_nav_list {
   my ($self, $locale, $ids, $wanted) = @_;

   my $iter = $self->iterator( $locale ); my @nav = ();

   while (defined (my $node = $iter->())) {
      $node->{id} eq 'index' and next;

      my $link = { level => $node->{level} - 2,
                   name  => $node->{name},
                   tip   => $self->_get_tip_text( $node ),
                   type  => $node->{type},
                   url   => $node->{type} eq 'folder' ? '#' : $node->{url}, };

      if (defined $ids->[ 0 ] and $ids->[ 0 ] eq $node->{id}) {
         $link->{class} = $node->{url} eq $wanted ? 'active' : 'open';
         shift @{ $ids };
      }

      push @nav, $link;
   }

   return \@nav;
}

sub _delete_and_prune {
   my ($self, $path) = @_;

   $path->exists and $path->unlink; __prune( $path );

   $self->_invalidate_cache;

   return $path->abs2rel( $self->config->file_root );
}

sub _docs_url {
   my ($self, $locale) = @_; state $cache //= {};

   my $mtime = $self->_localised_tree( $locale )->{tree}->{_mtime};
   my $lang  = __extract_lang( $locale );
   my $entry = $cache->{ $lang };

   (not $entry or $mtime > $entry->{mtime}) and $cache->{ $lang } = $entry
      = { mtime => $mtime, url => $self->_find_docs_url( $locale ), };

   return $entry->{url};
}

sub _find_docs_url {
   my ($self, $locale) = @_; my $iter = $self->iterator( $locale );

   while (defined (my $node = $iter->())) {
      $node->{type} eq 'file' and $node->{id} ne 'index'
         and return $node->{url};
   }

   my $error = "Config Error: Unable to find the first page in\n"
      ."the /docs folder. Double check you have at least one file in the root\n"
      ."of the /docs folder. Also make sure you do not have any empty folders";

   $self->log->fatal( $error );
   return '/';
}

sub _find_node {
   my ($self, $locale, $ids) = @_; my $tree = $self->_localised_tree( $locale );

   $ids //= []; $ids->[ 0 ] or $ids->[ 0 ] = 'index';

   for my $node_id (@{ $ids }) {
      $tree->{type} eq 'folder' and $tree = $tree->{tree};
      exists  $tree->{ $node_id } or return FALSE;
      $tree = $tree->{ $node_id };
   }

   return $tree;
}

sub _get_format {
   my ($self, $path) = @_; my $extn = (split m{ \. }mx, $path)[ -1 ] || NUL;

   return $self->type_map->{ $extn } || 'text';
}

sub _get_tip_text {
   my ($self, $node) = @_;

   my $text = $node->{path}->abs2rel( $self->config->file_root );

   $text =~ s{ \A [a-z]+ / }{}mx;
   $text =~ s{ [/] }{ / }gmx;
   $text =~ s{ \. .+ \z }{}mx;
   return $text;
}

sub _localised_tree {
   my ($self, $locale) = @_;

   my $lang = __extract_lang( $locale ); my $tree = $self->docs_tree;

   $lang and defined $tree->{ $lang } and return $tree->{ $lang };
   $lang = __extract_lang( $self->config->locale );
   $lang and defined $tree->{ $lang } and return $tree->{ $lang };

   return $tree->{ LANG() };
}

sub _make_page {
   my ($self, $req, $locale, $node) = @_;

   return { content  => $node->{path  },
            docs_url => $req->uri_for( $self->_docs_url( $locale ) ),
            format   => $node->{format},
            header   => $node->{title },
            mtime    => $node->{mtime },
            title    => ucfirst $node->{name},
            url      => $node->{url   }, };
}

sub _new_node {
   my ($self, $locale, $param) = @_;

   my $pathname =  __append_suffix( __get_or_throw( $param, 'pathname' ) );
   my @pathname =  __prepare_path( $pathname );
   my @filepath =  map { __make_id_from( $_ ) } @pathname;
   my $url      =  join '/', @filepath;
   my $id       =  pop @filepath;
   my $lang     =  __extract_lang( $locale );
   my $path     =  $self->config->file_root->catfile( $lang, @pathname )->utf8;
   my $parent   =  $self->_find_node( $locale, [ @filepath ] );

   $parent and $parent->{type} eq 'folder'
      and exists $parent->{tree}->{ $id }
      and $parent->{tree}->{ $id }->{path} eq $path
      and throw error => 'Path [_1] already exists',
                 args => [ join '/', $lang, @pathname ];

   return { path => $path, url => $url, };
}

sub _not_found {
   my ($self, $req) = @_;

   my $rv      = HTTP_NOT_FOUND;
   my $title   = $req->loc( 'Not found' );
   my $content = '> '.$req->loc( "Oh no. That page doesn't exist" )
                 ."\n\n    Code: ${rv}\n\n";

   return { content  => $content,
            docs_url => $req->uri_for( $self->_docs_url( $req->locale ) ),
            format   => 'markdown',
            header   => $title,
            mtime    => time,
            title    => $title, };
}

sub _search_results {
   my ($self, $req, $langd, $results) = @_;

   my $title   = $req->loc( 'Search Results' );
   my @tuples  = __prepare_search_results( $req, $langd, $results );
   my $content = join "\n",
      map { '['.$_->[ 0 ].']('.$_->[ 1 ].') '.$_->[ 2 ].'  ' } @tuples;

   return { content  => $content,
            docs_url => $req->uri_for( $self->_docs_url( $req->locale ) ),
            format   => 'markdown',
            header   => $title,
            mtime    => time,
            title    => $title, };
}

# Private functions
sub __append_suffix {
   my $path = shift;

   $path !~ m{ \. [m][k]?[d][n]? \z }mx and $path .= '.md';

   return $path;
}

sub __copy_element_value {
   return [ "\$( 'upload-btn' ).addEvent( 'change', function( ev ) {",
            "   ev.stop(); \$( 'upload-path' ).value = this.value } )", ];
}

sub __defined_or_throw {
   my ($params, $name) = @_;

   defined (my $param = $params->{ $name })
      or throw class => Unspecified, args => [ $name ],
                  rv => HTTP_EXPECTATION_FAILED;

   return $param;
}

sub __extract_lang {
   my $locale = shift; return $locale ? (split m{ _ }mx, $locale)[ 0 ] : LANG;
}

sub __get_or_throw {
   my ($params, $name) = @_;

   my $param = __defined_or_throw( $params, $name )
      or throw class => Unspecified, args => [ $name ],
                  rv => HTTP_EXPECTATION_FAILED;

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

sub __make_tuple {
   my $node = shift;

   return [ 0, $node && $node->{type} eq 'folder'
               ? [ __sorted_keys( $node->{tree} ) ] : [], $node, ];
}

sub __prepare_path {
   return (map { s{ [ ] }{_}gmx; $_ }
           map { trim $_            } split m{ / }mx, $_[ 0 ]);
}

sub __prepare_search_results {
   my ($req, $langd, $results) = @_;

   my @tuples = map { [ split m{ : }mx, $_, 3 ] } split m{ \n }mx, $results;

   for my $tuple (@tuples) {
      my @pathname = __prepare_path( io( $tuple->[ 0 ] )->abs2rel( $langd ) );
      my @filepath = map { __make_id_from( $_ ) } @pathname;
      my $actionp  = join '/', @filepath;
      my $name     = __make_name_from( $actionp ); $name =~ s{/}{ / }gmx;

      $tuple->[ 0 ] = $name; $tuple->[ 1 ] = $req->uri_for( $actionp );
   }

   return @tuples;
}

sub __prune {
   my $path = shift; my $dir = $path->parent;

   # TODO: The empty call is deprecated in favour of is_empty
   while ($dir->exists and $dir->empty) { $dir->rmdir; $dir = $dir->parent }

   return $dir;
}

sub __set_element_focus {
   my ($form, $name) = @_;

   return [ "var form = document.forms[ '${form}' ];",
            "var f    = function() { form.${name}.focus() };",
            "f.delay( 100 );" ];
}

sub __sorted_keys {
   my $node = shift;

   return ( sort { $node->{ $a }->{_order} <=> $node->{ $b }->{_order} }
            grep { first_char $_ ne '_' } keys %{ $node } );
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
