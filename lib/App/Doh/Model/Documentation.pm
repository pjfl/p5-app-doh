package App::Doh::Model::Documentation;

use 5.010001;
use namespace::sweep;

use Moo;
use Class::Usul::Constants;
use Class::Usul::Functions qw( throw );
use File::DataClass::IO;
use File::DataClass::Types qw( HashRef Str );

extends q(App::Doh);
with    q(App::Doh::Role::CommonLinks);
with    q(App::Doh::Role::PageConfiguration);
with    q(App::Doh::Role::Preferences);

# Public attributes
has 'docs_tree' => is => 'lazy', isa => HashRef;

has 'type_map'  => is => 'lazy', isa => HashRef, default => sub { {} };

has 'no_index'  => is => 'lazy', isa => Str,
   builder      => sub { join '|', @{ $_[ 0 ]->config->no_index } };

# Construction
sub _build_docs_tree {
   my ($self, $dir, $url_base, $title) = @_;

   my $no_index = $self->no_index; my $tree = {};

   state $level //= 0; $level++; state $order //= 0;

   $dir //= $self->config->file_root; $url_base //= NUL; $title //= NUL;

   for my $path ($dir->filter( sub { not m{ (?: $no_index ) }mx } )->all) {
      my $id         =  __make_id_from  ( $path->filename );
      my $name       =  __make_name_from( $id );
      my $url        =  $url_base ? "${url_base}/${id}"  : $id;
      my $full_title =  $title    ? "${title} - ${name}" : $name;
      my $node       =  $tree->{ $id } = {
         clean       => $id,
         format      => $self->_get_format( $path->pathname ),
         name        => $name,
         path        => $path->utf8,
         mtime       => $path->stat->{mtime},
         title       => $full_title,
         type        => 'file',
         url         => $url,
         _order      => $order++, };

      $path->is_dir or next;
      $node->{type} = 'folder';
      $node->{tree} = $level > 1
                    ? $self->_build_docs_tree( $path, $url, $name )
                    : $self->_build_docs_tree( $path, NUL, NUL    );
   }

   return $tree;
}

# Public methods
sub get_stash {
   my ($self, $req) = @_; my $args = $req->{args}; my $template;

   defined $args->[ 0 ] and $args->[ 0 ] ne 'index'
       and $template = 'documentation';

   return { nav      => $self->navigation( $req ),
            page     => $self->load_page ( $req ),
            template => $template, };
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

   my $node = $self->_find_node( $req );
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
      mode         => $req->params->{mode} // 'live',
      mtime        => $node->{mtime},
      title        => ucfirst $node->{name}, };

   my $title = $req->loc( 'Not found' );

   return { content      => '> '.$req->loc( "Oh no. That page doesn't exist" ),
            docs_url     => $url,
            editing      => FALSE,
            format       => 'markdown',
            header       => $title,
            homepage_url => $home,
            mtime        => time,
            title        => $title, };
}

sub navigation {
   my ($self, $req) = @_; my $names = [ @{ $req->args } ];

   my $tree = $self->_localised_tree( $req->locale )->{tree};

   return __build_navigation_list( $tree, $names, (join '/', @{ $names }), 0 );
}

sub update_file {
   my ($self, $req) = @_;

   $req->username ne 'unknown' or throw 'Update not authorised';

   my $node     = $self->_find_node( $req )
      or throw 'Cannot find document tree node to update';
   my $content  = $req->body->param->{content}; $content =~ s{ \r\n }{\n}gmx;
   my $path     = $node->{path}; $path->print( $content );
   my $rel_path = $path->abs2rel( $self->config->file_root );
   my $message  = [ 'File [_1] updated by [_2]', $rel_path, $req->username ];

   $node->{mtime} = $path->stat->{mtime};

   return { redirect => { location => $req->uri, message => $message } };
}

# Private methods
sub _docs_url {
   my ($self, $locale) = @_; my $lang = __extract_lang( $locale );

   state $urls //= {}; defined $urls->{ $lang } and return $urls->{ $lang };

   my $iter = $self->iterator( $locale );

   while (defined (my $node = $iter->())) {
      $node->{type} eq 'file' and $node->{name} ne 'index'
         and return $urls->{ $lang } = $node->{url};
   }

   my $error = "Config Error: Unable to find the first page in\n"
      ."the /docs folder. Double check you have at least one file in the root\n"
      ."of the /docs folder. Also make sure you do not have any empty folders";

   $self->log->fatal( $error );
   return '/';
}

sub _find_node {
   my ($self, $req) = @_;

   my $tree  = $self->_localised_tree( $req->locale )->{tree};
   my $names = [ @{ $req->args } ]; $names->[ 0 ] or $names->[ 0 ] = 'index';

   for my $node_name (@{ $names }) {
      $node_name or $node_name = 'index';
      exists  $tree->{ $node_name } or return FALSE;
      $tree = $tree->{ $node_name }->{type} eq 'folder'
            ? $tree->{ $node_name }->{tree} : $tree->{ $node_name };
   }

   return $tree;
}

sub _get_format {
   my ($self, $path) = @_; my $extn = (split m{ \. }mx, $path)[ -1 ] || NUL;

   return $self->type_map->{ $extn } || 'text';
}

sub _localised_tree {
   my ($self, $locale) = @_; my $lang = __extract_lang( $locale );

   $lang and defined $self->docs_tree->{ $lang }
         and return  $self->docs_tree->{ $lang };
   $lang = __extract_lang( $self->config->locale );
   $lang and defined $self->docs_tree->{ $lang }
         and return  $self->docs_tree->{ $lang };

   return $self->docs_tree->{ LANG };
}

# Private functions
sub __build_navigation_list {
   my ($tree, $names, $path_url, $level) = @_; my @nav = ();

   for my $node (map  { $tree->{ $_ } }
                 grep { $_ ne 'index' } __sort_pages( $tree )) {
      my $page = { level => $level, name => $node->{name},
                   type  => $node->{type} };

      if (defined $names->[ 0 ] and $names->[ 0 ] eq $node->{clean}) {
         $page->{class} = $path_url eq $node->{url} ? 'active' : 'open';
         shift @{ $names };
      }

      if ($page->{type} eq 'folder') {
         $page->{url} = '#';
         push @nav, $page, @{ __build_navigation_list
                             ( $node->{tree}, $names, $path_url, $level + 1 ) };
      }
      else { $page->{url} = $node->{url}; push @nav, $page }
   }

   return \@nav;
}

sub __current {
   my $href = shift;

   exists $href->{_iterator}
       or $href->{_iterator} = [ 0, __sort_pages( $href ) ];

   my $key = $href->{_iterator}->[ $href->{_iterator}->[ 0 ] + 1 ] or return;

   return $href->{ $key };
}

sub __extract_lang {
   my $locale = shift; return $locale ? (split m{ _ }mx, $locale)[ 0 ] : LANG;
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

sub __sort_pages {
   my $href = shift;

   return ( sort { $href->{ $a }->{_order} cmp $href->{ $b }->{_order} }
            grep { $_ ne '_iterator' } keys %{ $href } );
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
