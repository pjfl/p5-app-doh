package App::Doh::Model::Documentation;

use feature 'state';
use namespace::sweep;

use Moo;
use App::Doh::Functions    qw( build_tree extract_lang iterator localise_tree
                               make_id_from make_name_from mtime );
use Class::Usul::Constants;
use Class::Usul::Functions qw( first_char throw trim );
use Class::Usul::IPC;
use File::DataClass::IO;
use File::DataClass::Types qw( Object Path );
use HTTP::Status           qw( HTTP_EXPECTATION_FAILED HTTP_NOT_FOUND
                               HTTP_PRECONDITION_FAILED
                               HTTP_REQUEST_ENTITY_TOO_LARGE
                               HTTP_UNAUTHORIZED );
use Unexpected::Functions  qw( Unspecified );

extends q(App::Doh::Model);
with    q(App::Doh::Role::CommonLinks);
with    q(App::Doh::Role::PageConfiguration);
with    q(App::Doh::Role::Preferences);

# Public attributes
has 'ipc'        => is => 'lazy', isa => Object,
   builder       => sub { Class::Usul::IPC->new( builder => $_[ 0 ]->usul ) };

has 'root_mtime' => is => 'lazy', isa => Path, coerce => Path->coercion,
   builder       => sub { $_[ 0 ]->config->file_root->catfile( '.docs' ) };

with q(App::Doh::Role::PageLoading);

# Construction
around 'load_page' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $page = $self->load_localised_page( $orig, $req, @args );

   $page->{docs_url} //= $self->docs_url( $req );
   $page->{wanted  } //= join '/', @{ $req->args };

   return $page;
};

around 'make_page' => sub {
   my ($orig, $self, $node, $req, $locale) = @_;

   my $page = $orig->( $self, $node, $req, $locale );

   $page->{docs_url} = $self->docs_url( $req, $locale );

   return $page;
};

# Public methods
sub create_file_action {
   my ($self, $req) = @_;

   $req->username ne 'unknown'
      or throw error => 'File creation not authorised',
                  rv => HTTP_UNAUTHORIZED;

   my $new_node = $self->_new_node( $req->locale, $req->body_params );
   my $content  = $req->loc( $self->config->default_content );
   my $path     = $new_node->{path};

   $path->assert_filepath->println( $content )->close;
   $self->invalidate_cache( $path->stat->{mtime} );

   my $location = $req->uri_for( $new_node->{url} );
   my $rel_path = $path->abs2rel( $self->config->file_root );
   my $message  = [ 'File [_1] created by [_2]', $rel_path, $req->username ];

   return { redirect => { location => $location, message => $message } };
}

sub dialog {
   my ($self, $req) = @_;

   my $params = $req->query_params;
   my $name   = $params->( 'name' );
   my $page   = { meta => { id       => $params->( 'id' ),
                            template => "${name}-file", }, };

   if    ($name eq 'create') {
      $page->{literal_js} = __set_element_focus( "${name}-file", 'pathname' );
   }
   elsif ($name eq 'rename') {
      $page->{literal_js} = __set_element_focus( "${name}-file", 'pathname' );
      $page->{old_path  } = $params->( 'val' );
   }
   elsif ($name eq 'search') {
      $page->{literal_js} = __set_element_focus( "${name}-file", 'query' );
   }
   elsif ($name eq 'upload') {
      $page->{literal_js} = __copy_element_value();
   }

   return $self->get_stash( $req, $page );
}

sub delete_file_action {
   my ($self, $req) = @_;

   $req->username ne 'unknown'
      or throw error => 'File deletion not authorised',
                  rv => HTTP_UNAUTHORIZED;

   my $node     = $self->find_node( $req->locale, [ @{ $req->args } ] )
      or throw error => 'Cannot find document tree node to delete',
                  rv => HTTP_NOT_FOUND;
   my $rel_path = $self->_delete_and_prune( $node->{path} );
   my $message  = [ 'File [_1] deleted by [_2]', $rel_path, $req->username ];
   my $location = $self->docs_url( $req );

   return { redirect => { location => $location, message => $message } };
}

sub docs_tree {
   my $self = shift; state $cache; my $filesys = $self->root_mtime;

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

sub generate_static_action {
   my ($self, $req) = @_;

   $req->username ne 'unknown'
      or throw error => 'File deletion not authorised',
                  rv => HTTP_UNAUTHORIZED;

   my $cli = $self->config->binsdir->catfile( 'doh-cli' );
   my $cmd = [ "${cli}", 'make_static' ];

   $self->log->debug( $self->ipc->run_cmd( $cmd, { async => TRUE } )->out );

   my $location = $self->docs_url( $req );
   my $message  = [ 'Static page generation started in the background by [_1]',
                    $req->username ];

   return { redirect => { location => $location, message => $message } };
}

sub locales {
   return grep { first_char $_ ne '_' } keys %{ $_[ 0 ]->docs_tree };
}

sub localised_tree {
   return localise_tree $_[ 0 ]->docs_tree, $_[ 1 ];
}

sub rename_file_action {
   my ($self, $req) = @_;

   $req->username ne 'unknown'
      or throw error => 'File renaming not authorised',
                  rv => HTTP_UNAUTHORIZED;

   my $params   = $req->body_params;
   my $old_path = [ split m{ / }mx, $params->( 'old_path' ) ];
   my $node     = $self->find_node( $req->locale, $old_path )
      or throw error => 'Cannot find document tree node to rename',
                  rv => HTTP_NOT_FOUND;
   my $new_node = $self->_new_node( $req->locale, $params );

   $new_node->{path}->assert_filepath;
   $node->{path}->close->move( $new_node->{path} ); __prune( $node->{path} );
   $self->invalidate_cache;

   my $location = $req->uri_for( $new_node->{url} );
   my $rel_path = $node->{path}->abs2rel( $self->config->file_root );
   my $message  = [ 'File [_1] renamed by [_2]', $rel_path, $req->username ];

   return { redirect => { location => $location, message => $message } };
}

sub save_file_action {
   my ($self, $req) = @_;

   $req->username ne 'unknown'
      or throw error => 'File updating not authorised',
                  rv => HTTP_UNAUTHORIZED;

   my $node     =  $self->find_node( $req->locale, [ @{ $req->args } ] )
      or throw error => 'Cannot find document tree node to update',
                  rv => HTTP_NOT_FOUND;
   my $content  =  $req->body_value( 'content' );
      $content  =~ s{ \r\n }{\n}gmx; $content =~ s{ \s+ \z }{}mx;
   my $path     =  $node->{path}; $path->println( $content ); $path->close;
   my $rel_path =  $path->abs2rel( $self->config->file_root );
   my $message  =  [ 'File [_1] updated by [_2]', $rel_path, $req->username ];

   $node->{mtime} = $path->stat->{mtime};

   return { redirect => { location => $req->uri, message => $message } };
}

sub search_document_tree {
   my ($self, $req) = @_;

   my $page = $self->_search_results( $req, $req->query_params->( 'query' ) );

   return $self->get_stash( $req, $self->load_page( $req, $page ) );
}

sub upload_file {
   my ($self, $req) = @_; my $conf = $self->config;

   my $upload = $req->args->[ 0 ]
      or  throw class => Unspecified, args => [ 'upload object' ],
                   rv => HTTP_EXPECTATION_FAILED;

   $upload->is_upload
      or  throw error => $upload->reason, rv => HTTP_EXPECTATION_FAILED;

   $upload->size > $conf->max_asset_size
      and throw error => 'File [_1] size [_2] too big',
                 args => [ $upload->filename, $upload->size ],
                   rv => HTTP_REQUEST_ENTITY_TOO_LARGE;

   $req->username ne 'unknown'
      or  throw error => 'File uploading not authorised',
                   rv => HTTP_UNAUTHORIZED;

   my $path = $conf->assetdir->catfile( $upload->filename );

   io( $upload->path )->copy( $path->assert_filepath );

   my $rel_path = $path->abs2rel( $self->config->assetdir );
   my $message  = [ 'File [_1] uploaded by [_2]', $rel_path, $req->username ];
   my $location = $self->docs_url( $req );

   return { redirect => { location => $location, message => $message } };
}

# Private methods
sub _delete_and_prune {
   my ($self, $path) = @_;

   $path->exists and $path->unlink; __prune( $path );

   $self->invalidate_cache;

   return $path->abs2rel( $self->config->file_root );
}

sub _docs_url {
   my ($self, $locale) = @_; state $cache //= {};

   my $node  = $self->localised_tree( $locale )
      or throw error => 'No document tree for locale [_1]',
                args => [ $locale ], rv => HTTP_NOT_FOUND;
   my $mtime = mtime $node;
   my $lang  = extract_lang $locale;
   my $entry = $cache->{ $lang };

   (not $entry or $mtime > $entry->{mtime}) and $cache->{ $lang } = $entry
      = { mtime => $mtime, url => $self->_find_first_url( $locale ), };

   return $entry->{url};
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

sub _new_node {
   my ($self, $locale, $params) = @_;

   my $lang     = extract_lang $locale;
   my @pathname = __prepare_path( __append_suffix( $params->( 'pathname' ) ) );
   my $path     = $self->config->file_root->catfile( $lang, @pathname )->utf8;
   my @filepath = map { make_id_from( $_ )->[ 0 ] } @pathname;
   my $url      = join '/', @filepath;
   my $id       = pop @filepath;
   my $parent   = $self->find_node( $locale, [ @filepath ] );

   $parent and $parent->{type} eq 'folder'
      and exists $parent->{tree}->{ $id }
      and $parent->{tree}->{ $id }->{path} eq $path
      and throw error => 'Path [_1] already exists',
                 args => [ join '/', $lang, @pathname ],
                   rv => HTTP_PRECONDITION_FAILED;

   return { path => $path, url => $url, };
}

sub _search_results {
   my ($self, $req, $query) = @_;

   my $count   = 1;
   my $root    = $self->config->file_root;
   my $langd   = $root->catdir( extract_lang $req->locale );
   my $resp    = $self->ipc->run_cmd( [ 'ack', $query, "${langd}" ],
                 { debug => $self->usul->debug, expected_rv => 1 } );
   my $results = $resp->rv == 1
               ? $langd->catfile( $req->loc( 'Nothing found' ) ).'::'
               : $resp->stdout;
   my @tuples  = __prepare_search_results( $req, $langd, $results );
   my $content = join "\n\n", map { __result_line( $count++, $_ ) } @tuples;
   my $leader  = $req->loc( 'You searched for "[_1]"', $query )."\n\n";
   my $title   = $req->loc( 'Search Results' );

   return { content  => $leader.$content,
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

sub __prepare_path {
   return (map { s{ [ ] }{_}gmx; $_ }
           map { trim $_            } split m{ / }mx, $_[ 0 ]);
}

sub __prepare_search_results {
   my ($req, $langd, $results) = @_;

   my @tuples = map { [ split m{ : }mx, $_, 3 ] } split m{ \n }mx, $results;

   for my $tuple (@tuples) {
      my @pathname = __prepare_path( io( $tuple->[ 0 ] )->abs2rel( $langd ) );
      my @filepath = map { make_id_from( $_ )->[ 0 ] } @pathname;
      my $actionp  = join '/', @filepath;
      my $name     = make_name_from $actionp; $name =~ s{/}{ / }gmx;

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

sub __result_line {
   return $_[ 0 ].'\. ['.$_[ 1 ]->[ 0 ].']('.$_[ 1 ]->[ 1 ].")\n\n"
         .$_[ 1 ]->[ 2 ];
}

sub __set_element_focus {
   my ($form, $name) = @_;

   return [ "var form = document.forms[ '${form}' ];",
            "var f    = function() { form.${name}.focus() };",
            "f.delay( 100 );" ];
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
