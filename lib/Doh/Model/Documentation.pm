# @(#)Ident: Documentation.pm 2013-08-22 20:53 pjf ;

package Doh::Model::Documentation;

use 5.010001;
use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 19 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use File::DataClass::IO;
use File::DataClass::Types  qw( HashRef NonEmptySimpleStr );
use File::Spec::Functions   qw( curdir );
use Moo;

extends q(Doh);
with    q(Doh::TraitFor::CommonLinks);
with    q(Doh::TraitFor::Preferences);

# Public attributes
has 'docs_tree' => is => 'lazy', isa => HashRef;

has 'docs_url'  => is => 'lazy', isa => NonEmptySimpleStr;

has 'type_map'  => is => 'lazy', isa => HashRef, default => sub { {} };

# Construction
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
   my ($self, $req) = @_; my $doc_path = [ @{ $req->args } ]; my $tree;

   my $node = __find_node( $tree = $self->docs_tree, $doc_path );

   ($node and exists $node->{type} and $node->{type} eq 'file')
      or return { content => "> Oh no. That page doesn't exist",
                  format  => 'markdown' };

   my $home = exists $tree->{index} ? '/' : $self->docs_url;
   my $page = { content      => io( $node->{path} ),
                docs_url     => $self->uri_for( $req, $self->docs_url ),
                format       => $node->{format},
                homepage_url => $self->uri_for( $req, $home ),
   };

   $node->{name} ne 'index' and $page->{header} = $node->{title};

   return $page;
}

sub navigation {
   my ($self, $req) = @_; my $parts = [ @{ $req->args } ];

   return __build_navigation_list( $self->docs_tree, $parts,
                                   (join '/', NUL, @{ $parts }), 0 );
}

# Private methods
sub _build_docs_tree {
   my ($self, $path, $clean_path, $title) = @_; state $index //= 0;

   $path //= $self->config->docs_path; $clean_path //= NUL; $title //= NUL;

   my $re  = join '|', @{ $self->config->no_index }; my $tree = {};

   for my $file (io( $path )->filter( sub { not m{ (?: $re ) }mx } )->all) {
      my $clean_sort =  __clean_sort( $file->filename );
      my $url        =  "${clean_path}/${clean_sort}";
      my $clean_name =  __clean_name( $clean_sort );
      my $full_path  =  $file->pathname;
      my $full_title =  $title ? "${title}: ${clean_name}" : $clean_name;
      my $node       =  $tree->{ $clean_sort } = {
         clean       => $clean_sort,
         format      => $self->_get_format( $full_path ),
         name        => $clean_name,
         path        => $full_path,
         title       => $full_title,
         type        => 'file',
         url         => $url,
         _order      => $index++, };

      $file->is_dir or next;
      $node->{tree} = $self->_build_docs_tree( $full_path, $url, $full_title );
      $node->{type} = 'folder';
   }

   return $tree;
}

sub _build_docs_url {
   my ($self, $tree, $node) = @_;

   $tree //= $self->docs_tree; $node //= __current( $tree );

   if ($node->{type} eq 'file') { return $node->{url} }
   elsif (exists $node->{tree}) {
      return $self->_build_docs_url( $node->{tree} );
   }

   $node = __next( $tree ) or $self->log->fatal( 'Config Error: Unable to find the first page in the /docs folder. Double check you have at least one file in the root of of the /docs folder. Also make sure you do not have any empty folders' );

   return $self->_build_docs_url( $tree, $node );
}

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
                                 ( $node->{tree}, $parts,
                                   $path_url, $level + 1 ) };
      }
      else { $page->{url} = $node->{url}; push @nav, $page }
   }

   return \@nav;
}

sub __clean_name {
   my $text = shift; $text =~ s{ [_] }{ }gmx; return $text;
}

sub __clean_sort {
   my $text = shift;

   $text =~ s{ \A \d+ [_] }{}mx; $text =~ s{ \. [a-zA-Z0-9_\+]+ \z }{}mx;

   return $text;
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
