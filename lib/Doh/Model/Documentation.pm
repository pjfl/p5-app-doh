# @(#)Ident: Documentation.pm 2013-07-20 20:34 pjf ;

package Doh::Model::Documentation;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 10 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use File::DataClass::IO;
use File::DataClass::Types  qw( HashRef NonEmptySimpleStr );
use File::Spec::Functions   qw( curdir );
use Moo;

extends q(Doh);

# Public attributes
has 'docs_tree' => is => 'lazy', isa => HashRef;

has 'docs_url'  => is => 'lazy', isa => NonEmptySimpleStr;

# Construction
sub BUILD {
   $_[ 0 ]->docs_url; return;
}

# Public methods
sub get_stash {
   my ($self, $req) = @_; my $conf = $self->config; my $tree = $self->docs_tree;

   my $template = $req->{args}->[ 0 ] ? 'documentation' : 'index';

   return {
      config       => $conf,
      docs_url     => $self->docs_url,
      homepage_url => exists $tree->{index} ? '/' : $self->docs_url,
      http_host    => $req->{env}->{HTTP_HOST},
      nav          => __build_nav( $tree, [ @{ $req->{args} } ] ),
      page         => __load_page( $tree, [ @{ $req->{args} } ] ),
      template     => $template,
      theme        => $req->{params}->{ 'theme' } || $conf->theme,
   };
}

# Private methods
sub _build_docs_tree {
   my ($self, $path, $clean_path, $title) = @_; my $tree = {};

   $path //= $self->config->docs_path; $clean_path //= NUL; $title //= NUL;

   my $filter = sub { not m{ (?: doh.json | cgi-bin ) }mx }; my $index = 0;

   for my $file (io( $path )->filter( $filter )->all) {
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
   my ($self, $tree, $branch) = @_;

   $tree //= $self->docs_tree; $branch //= __current( $tree );

   if ($branch->{type} eq 'file') { return $branch->{url} }
   elsif (exists $branch->{tree}) {
      return $self->_build_docs_url( $branch->{tree} );
   }

   $branch = __next( $tree ) or $self->log->fatal( 'Config Error: Unable to find the first page in the /docs folder. Double check you have at least one file in the root of of the /docs folder. Also make sure you do not have any empty folders' );

   return $self->_build_docs_url( $tree, $branch );
}

sub _get_format {
   my ($self, $path) = @_; my $extn = (split m{ \. }mx, $path)[ -1 ] || NUL;

   return $self->type_map->{ $extn } || 'text';
}

# Private functions
sub __build_nav {
   my ($tree, $parts, $path_url, $level) = @_; my @nav = ();

   $path_url //= join '/', NUL, @{ $parts }; $level //= 0;

   for my $node (map  { $tree->{ $_ } }
                 grep { $_ ne 'index' } __sort_pages( $tree )) {
      my $page = { level => $level, name => $node->{name},
                   type  => $node->{type} };

      if (defined $parts->[ 0 ] and $parts->[ 0 ] eq $node->{clean}) {
         $page->{class} = $path_url eq $node->{url} ? 'active' : 'open';
         shift @{ $parts };
      }

      if ($page->{type} eq 'folder') {
         $page->{url} = '#'; push @nav, $page;
         push @nav, @{ __build_nav( $node->{tree}, $parts,
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
   my $text = shift; $text =~ s{ \A \d+ [_] }{}mx;

   $text =~ s{ (?: \.mkdn | \.md | \.pod ) \z }{}mx;

   return $text;
}

sub __current {
   my $href = shift;

   exists $href->{_iterator}
      or $href->{_iterator} = [ 0, __sort_pages( $href ) ];

   return $href->{ $href->{_iterator}->[ $href->{_iterator}->[ 0 ] + 1 ] };
}

sub __find_branch {
   my ($tree, $path) = @_; $path->[ 0 ] or $path->[ 0 ] = 'index';

   for my $node (@{ $path }) {
      $node or $node = 'index'; exists $tree->{ $node } or return FALSE;

      $tree = $tree->{ $node }->{type} eq 'folder'
            ? $tree->{ $node }->{tree} : $tree->{ $node };
   }

   return $tree;
}

sub __load_page {
   my ($tree, $path) = @_; my $branch = __find_branch( $tree, $path );

   ($branch and exists $branch->{type} and $branch->{type} eq 'file')
      or return { content => "> Oh no. That page doesn't exist",
                  format  => 'markdown' };

   my $page = { content => io( $branch->{path} )->utf8->all,
                format  => $branch->{format}, };

   $branch->{name} ne 'index' and $page->{header} = $branch->{title};

   return $page;
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
