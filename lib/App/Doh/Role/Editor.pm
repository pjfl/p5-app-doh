package App::Doh::Role::Editor;

use namespace::autoclean;

use App::Doh::Util         qw( make_id_from make_name_from mtime
                               set_element_focus stash_functions );
use Class::Usul::Constants qw( EXCEPTION_CLASS FALSE TRUE );
use Class::Usul::Functions qw( io is_member throw trim untaint_path );
use Class::Usul::Time      qw( time2str );
use Class::Usul::Types     qw( CodeRef );
use HTTP::Status           qw( HTTP_EXPECTATION_FAILED HTTP_NOT_FOUND
                               HTTP_PRECONDITION_FAILED
                               HTTP_REQUEST_ENTITY_TOO_LARGE );
use Unexpected::Functions  qw( Unspecified );
use Moo::Role;

requires qw( config find_node get_content initialise_stash
             invalidate_cache load_page log run_cmd );

with 'Web::Components::Role::TT';

# Private functions
my $_append_suffix = sub {
   my $path = untaint_path $_[ 0 ];

   $path !~ m{ \. [m][k]?[d][n]? \z }mx and $path .= '.md';

   return $path;
};

my $_copy_element_value = sub {
   return [ "\$( 'upload-btn' ).addEvent( 'change', function( ev ) {",
            "   ev.stop(); \$( 'upload-path' ).value = this.value } )", ];
};

my $_make_draft = sub {
   my ($conf, @pathname) = @_;

   if ($pathname[ 0 ] eq $conf->posts) {
      shift @pathname; return $conf->posts, $conf->drafts, @pathname;
   }

   return $conf->drafts, @pathname;
};

my $_prepare_path = sub {
   my $path = shift; $path =~ s{ [\\] }{/}gmx;

   return (map { s{ [ ] }{_}gmx; $_ }
           map { trim $_            } split m{ / }mx, $path);
};

my $_prepare_search_results = sub {
   my ($req, $langd, $results) = @_;

   my @tuples = map { [ split m{ : }mx, $_, 3 ] } split m{ \n }mx, $results;

   for my $tuple (@tuples) {
      my @pathname = $_prepare_path->( io( $tuple->[ 0 ] )->abs2rel( $langd ) );
      my @filepath = map { make_id_from( $_ )->[ 0 ] } @pathname;
      my $actionp  = join '/', @filepath;
      my $name     = make_name_from $actionp; $name =~ s{/}{ / }gmx;

      $tuple->[ 0 ] = $name; $tuple->[ 1 ] = $req->uri_for( $actionp );
   }

   return @tuples;
};

my $_prune = sub {
   my $path = shift; my $dir = $path->parent;

   while ($dir->exists and $dir->is_empty) { $dir->rmdir; $dir = $dir->parent }

   return $dir;
};

my $_result_line = sub {
   return $_[ 0 ].'\. ['.$_[ 1 ]->[ 0 ].']('.$_[ 1 ]->[ 1 ].")\n\n> "
         .$_[ 1 ]->[ 2 ];
};

# Private methods
my $_new_node = sub {
   my ($self, $locale, $pathname, $draft) = @_; my $conf = $self->config;

   my @pathname = $_prepare_path->( $_append_suffix->( $pathname ) );

   $draft and @pathname = $_make_draft->( $conf, @pathname );

   my $path     = $conf->file_root->catfile( $locale, @pathname )->utf8;
   my @filepath = map { make_id_from( $_ )->[ 0 ] } @pathname;
   my $url      = join '/', @filepath;
   my $id       = pop @filepath;
   my $parent   = $self->find_node( $locale, \@filepath );

   $parent and $parent->{type} eq 'folder'
      and exists $parent->{tree}->{ $id }
      and $parent->{tree}->{ $id }->{path} eq $path
      and throw 'Path [_1] already exists', [ $path ],
                rv => HTTP_PRECONDITION_FAILED;

   return { path => $path, url => $url, };
};

my $_search_results = sub {
   my ($self, $req) = @_;

   my $count   = 1;
   my $query   = $req->query_params->( 'query' );
   my $localed = $self->config->file_root->catdir( $req->locale );
   my $resp    = $self->run_cmd
                 ( [ 'ack', $query, "${localed}" ], { expected_rv => 1, } );
   my $results = $resp->rv == 1
               ? $localed->catfile( $req->loc( 'Nothing found' ) ).'::'
               : $resp->stdout;
   my @tuples  = $_prepare_search_results->( $req, $localed, $results );
   my $content = join "\n\n", map { $_result_line->( $count++, $_ ) } @tuples;
   my $leader  = $req->loc( 'You searched for "[_1]"', $query )."\n\n";
   my $name    = $req->loc( 'Search Results' );

   return { content => $leader.$content,
            format  => 'markdown',
            mtime   => time,
            name    => $name,
            title   => ucfirst $name, };
};

# Public methods
sub create_file {
   my ($self, $req) = @_;

   my $conf     = $self->config;
   my $params   = $req->body_params;
   my $pathname = $params->( 'pathname' );
   my $draft    = $params->( 'draft', { optional => TRUE } ) || FALSE;
   my $new_node = $self->$_new_node( $req->locale, $pathname, $draft );
   my $created  = time2str '%Y-%m-%d %H:%M:%S %z', time, 'UTC';
   my $stash    = { page => { author  => $req->username,
                              created => $created,
                              layout  => $conf->blank_template, }, };

   stash_functions $self, $req, $stash;

   my $content  = $self->render_template( $stash );
   my $path     = $new_node->{path};

   $path->assert_filepath->println( $content )->close;
   $self->invalidate_cache( $path->stat->{mtime} );

   my $rel_path = $path->abs2rel( $conf->file_root );
   my $message  = [ 'File [_1] created by [_2]', $rel_path, $req->username ];
   my $location = $req->uri_for( $new_node->{url} );

   return { redirect => { location => $location, message => $message } };
}

sub delete_file {
   my ($self, $req) = @_;

   my $node     = $self->find_node( $req->locale, $req->uri_params->() )
      or throw 'Cannot find document tree node to delete', rv => HTTP_NOT_FOUND;
   my $path     = $node->{path};

   $path->exists and $path->unlink; $_prune->( $path ); $self->invalidate_cache;

   my $rel_path = $path->abs2rel( $self->config->file_root );
   my $message  = [ 'File [_1] deleted by [_2]', $rel_path, $req->username ];

   return { redirect => { location => $req->base, message => $message } };
}

sub dialog {
   my ($self, $req) = @_;

   my $params =  $req->query_params;
   my $name   =  $params->( 'name' );
   my $stash  =  $self->initialise_stash( $req );
   my $links  =  $stash->{links};
   my $postd  =  $self->config->posts;
   my $page   =  $stash->{page} = $self->load_page( $req, {
      layout  => "${name}-file",
      meta    => { id => $params->( 'id' ), }, } );

   if    ($name eq 'create') {
      $page->{literal_js} = set_element_focus "${name}-file", 'pathname';
   }
   elsif ($name eq 'rename') {
      $page->{literal_js } = set_element_focus "${name}-file", 'pathname';
      $page->{old_path   } = $params->( 'val' );
      $links->{rename_uri} = $page->{old_path} =~ m{ \A $postd }mx
                           ? $req->uri_for( $postd ) : $links->{base_uri};
   }
   elsif ($name eq 'search') {
      $page->{literal_js} = set_element_focus "${name}-file", 'query';
   }
   elsif ($name eq 'upload') {
      $page->{literal_js} = $_copy_element_value->();
   }

   $stash->{view} = 'json';
   return $stash;
}

sub rename_file {
   my ($self, $req) = @_;

   my $params   = $req->body_params;
   my $old_path = [ split m{ / }mx, $params->( 'old_path' ) ];

   $old_path->[ 0 ] eq $self->config->posts and shift @{ $old_path };

   my $node     = $self->find_node( $req->locale, $old_path )
      or throw 'Cannot find document tree node to rename', rv => HTTP_NOT_FOUND;
   my $new_node = $self->$_new_node( $req->locale, $params->( 'pathname' ) );

   $new_node->{path}->assert_filepath;
   $node->{path}->close->move( $new_node->{path} ); $_prune->( $node->{path} );
   $self->invalidate_cache;

   my $rel_path = $node->{path}->abs2rel( $self->config->file_root );
   my $message  = [ 'File [_1] renamed by [_2]', $rel_path, $req->username ];
   my $location = $req->uri_for( $new_node->{url} );

   return { redirect => { location => $location, message => $message } };
}

sub save_file {
   my ($self, $req) = @_;

   my $node     =  $self->find_node( $req->locale, $req->uri_params->() )
      or throw 'Cannot find document tree node to update', rv => HTTP_NOT_FOUND;
   my $content  =  $req->body_params->( 'content', { raw => TRUE } );
      $content  =~ s{ \r\n }{\n}gmx; $content =~ s{ \s+ \z }{}mx;
   my $path     =  $node->{path}; $path->println( $content ); $path->close;
   my $rel_path =  $path->abs2rel( $self->config->file_root );
   my $message  =  [ 'File [_1] updated by [_2]', $rel_path, $req->username ];

   $node->{mtime} = $path->stat->{mtime};

   return { redirect => { location => $req->uri, message => $message } };
}

sub search {
   my ($self, $req) = @_;

   return $self->get_content( $req, $self->$_search_results( $req ) );
}

sub upload {
   my ($self, $req) = @_; my $conf = $self->config;

   $req->has_upload and my $upload = $req->upload
      or  throw Unspecified, [ 'upload object' ], rv => HTTP_EXPECTATION_FAILED;

   $upload->is_upload or throw $upload->reason, rv => HTTP_EXPECTATION_FAILED;

   $upload->size > $conf->max_asset_size
      and throw 'File [_1] size [_2] too big',
                [ $upload->filename, $upload->size ],
                rv => HTTP_REQUEST_ENTITY_TOO_LARGE;

   my $dest = $conf->assetdir->catfile( $upload->filename )->assert_filepath;

   io( $upload->path )->copy( $dest );

   my $rel_path = $dest->abs2rel( $conf->assetdir );
   my $message  = [ 'File [_1] uploaded by [_2]', $rel_path, $req->username ];

   return { redirect => { location => $req->base, message => $message } };
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
