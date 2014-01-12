# @(#)Ident: Documentation.pm 2014-01-04 01:15 pjf ;

package App::Doh::Model::Documentation;

use 5.010001;
use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 27 $ =~ /\d+/gmx );

use Moo;
use Class::Usul::Constants;
use File::DataClass::IO;
use File::DataClass::Types  qw( HashRef NonEmptySimpleStr );
use File::Spec::Functions   qw( curdir );

extends q(App::Doh);
with    q(App::Doh::Role::CommonLinks);
with    q(App::Doh::Role::PageConfiguration);
with    q(App::Doh::Role::Preferences);

# Public attributes
has 'docs_tree' => is => 'lazy', isa => HashRef;

has 'docs_url'  => is => 'lazy', isa => NonEmptySimpleStr;

has 'type_map'  => is => 'lazy', isa => HashRef, default => sub { {} };

# Construction
sub _build_docs_tree {
   my ($self, $dir, $url_base, $title) = @_; state $index //= 0;

   $dir //= io( $self->config->docs_path ); $url_base //= NUL; $title //= NUL;

   my $re = join '|', @{ $self->config->no_index }; my $tree = {};

   for my $path ($dir->filter( sub { not m{ (?: $re ) }mx } )->all) {
      my $id         =  __make_id_from  ( $path->filename );
      my $name       =  __make_name_from( $id );
      my $url        =  $url_base ? "${url_base}/${id}"  : $id;
      my $full_title =  $title    ? "${title} - ${name}" : $name;
      my $node       =  $tree->{ $id } = {
         clean       => $id,
         format      => $self->_get_format( $path->pathname ),
         name        => $name,
         path        => $path->pathname,
         title       => $full_title,
         type        => 'file',
         url         => $url,
         _order      => $index++, };

      $path->is_dir or next;
      $node->{tree} = $self->_build_docs_tree( $path, $url, $name );
      $node->{type} = 'folder';
   }

   return $tree;
}

sub _build_docs_url {
   my ($self, $tree, $node) = @_;

   $tree //= $self->docs_tree; $node //= __current( $tree );

   $node->{type} eq 'file' and return $node->{url};
   exists $node->{tree}    and return $self->_build_docs_url( $node->{tree} );
   $node = __next( $tree ) and return $self->_build_docs_url( $tree, $node  );

   my $error = "Config Error: Unable to find the first page in\n"
      ."the /docs folder. Double check you have at least one file in the root\n"
      ."of the /docs folder. Also make sure you do not have any empty folders";

   $self->log->fatal( $error );
   return '/';
}

sub BUILD { # The docs_tree attribute constructor may take some time to run
   $_[ 0 ]->docs_url; return;
}

# Public methods
sub get_stash {
   my ($self, $req) = @_;

   return { nav      => $self->navigation( $req ),
            page     => $self->load_page ( $req ),
            template => $req->{args}->[ 0 ] ? 'documentation' : undef, };
}

sub load_page {
   my ($self, $req) = @_;

   my $tree = $self->docs_tree;
   my $node = __find_node( $tree, [ @{ $req->args } ] );
   my $home = $req->uri_for( exists $tree->{index} ? NUL : $self->docs_url );

   $node and exists $node->{type} and $node->{type} eq 'file'
      and return { content      => io( $node->{path} )->utf8,
                   docs_url     => $req->uri_for( $self->docs_url ),
                   format       => $node->{format},
                   header       => $node->{title},
                   homepage_url => $home,
                   title        => ucfirst $node->{name}, };

   return { content      => '> '.$req->loc( "Oh no. That page doesn't exist" ),
            docs_url     => $req->uri_for( $self->docs_url ),
            format       => 'markdown',
            homepage_url => $home,
            title        => $req->loc( 'Not found' ), };
}

sub navigation {
   my ($self, $req) = @_; my $parts = [ @{ $req->args } ];

   return __build_navigation_list
      ( $self->docs_tree, $parts, (join '/', @{ $parts }), 0 );
}

# Private methods
sub _get_format {
   my ($self, $path) = @_; my $extn = (split m{ \. }mx, $path)[ -1 ] || NUL;

   return $self->type_map->{ $extn } || 'text';
}

# Private functions
sub __build_navigation_list {
   my ($tree, $parts, $path_url, $level) = @_; my @nav = ();

   for my $node (map  { $tree->{ $_ } }
                 grep { $_ ne 'index' } __sort_pages( $tree )) {
      my $page = { level => $level, name => $node->{name},
                   type  => $node->{type} };

      if (defined $parts->[ 0 ] and $parts->[ 0 ] eq $node->{clean}) {
         $page->{class} = $path_url eq $node->{url} ? 'active' : 'open';
         shift @{ $parts };
      }

      if ($page->{type} eq 'folder') {
         $page->{url} = '#';
         push @nav, $page, @{ __build_navigation_list
                             ( $node->{tree}, $parts, $path_url, $level + 1 ) };
      }
      else { $page->{url} = $node->{url}; push @nav, $page }
   }

   return \@nav;
}

sub __current {
   my $href = shift;

   exists $href->{_iterator}
      or $href->{_iterator} = [ 0, __sort_pages( $href ) ];

   return $href->{ $href->{_iterator}->[ $href->{_iterator}->[ 0 ] + 1 ] };
}

sub __find_node {
   my ($tree, $path) = @_; $path->[ 0 ] or $path->[ 0 ] = 'index';

   for my $node (@{ $path }) {
      $node or $node = 'index'; exists $tree->{ $node } or return FALSE;

      $tree = $tree->{ $node }->{type} eq 'folder'
            ? $tree->{ $node }->{tree} : $tree->{ $node };
   }

   return $tree;
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
