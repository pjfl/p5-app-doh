# @(#)Ident: Documentation.pm 2013-07-14 23:21 pjf ;

package Doh::Model::Documentation;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 4 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Functions  qw( is_hashref trim );
use File::DataClass::IO;
use File::DataClass::Types  qw( HashRef NonEmptySimpleStr Object );
use File::Spec::Functions   qw( curdir );
use Moo;

# Public attributes
has 'docs_tree' => is => 'lazy', isa => HashRef,
   default      => sub { __get_tree( $_[ 0 ]->config->docs_path ) };

has 'docs_url'  => is => 'lazy', isa => NonEmptySimpleStr;

# Private attributes
has '_usul'     => is => 'ro',   isa => Object, handles => [ qw( config log ) ],
   init_arg     => 'builder', required => TRUE, weak_ref => TRUE;

# Public methods
sub get_stash {
   my ($self, @args) = @_;

   my $conf  = $self->config;
   my $url   = $self->docs_url;
   my $tree  = $self->docs_tree;
   my $env   = ($args[ -1 ] && is_hashref $args[ -1 ]) ? pop @args : {};
   my @parts = split m{ [/] }mx, trim $args[ 0 ] || 'index', '/';

   return {
      colours      => __to_array_of_hash( $conf->colours, qw( key value ) ),
      config       => $conf,
      docs_url     => $url,
      homepage     => $args[ 0 ] ? FALSE : TRUE,
      homepage_url => exists $tree->{index} ? '/' : $url,
      http_host    => $env->{HTTP_HOST},
      links        => __to_array_of_hash( $conf->links, qw( name url ) ),
      nav          => __build_nav( $tree, [ @parts ] ),
      page         => __load_page( $tree, [ @parts ] ),
   };
}

# Private methods
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
   my $text = shift;

   $text =~ s{ \A \d+ [_] }{}mx; $text =~ s{ (?: \.mkdn | \.md ) \z }{}mx;

   return $text;
}

sub __current {
   my $href = shift;

   exists $href->{_iterator}
      or $href->{_iterator} = [ 0, __sort_pages( $href ) ];

   return $href->{ $href->{_iterator}->[ $href->{_iterator}->[ 0 ] + 1 ] };
}

sub __find_branch {
   my ($tree, $path) = @_;

   for my $node (@{ $path }) {
      $node or $node = 'index'; exists $tree->{ $node } or return FALSE;

      $tree = $tree->{ $node }->{type} eq 'folder'
            ? $tree->{ $node }->{tree} : $tree->{ $node };
   }

   return $tree;
}

sub __get_tree {
   my ($path, $clean_path, $title) = @_;

   $path //= curdir; $clean_path //= NUL; $title //= NUL;

   my $dir   = io( $path )->filter
      ( sub { not m{ (?: config.json | cgi-bin ) }mx } );

   my $index = 0; my $tree = {};

   for my $file ($dir->all) {
      my $clean_sort = __clean_sort( $file->filename );
      my $url        = "${clean_path}/${clean_sort}";
      my $clean_name = __clean_name( $clean_sort );
      my $full_path  = $file->pathname;
      my $full_title;

      if ($title) { $full_title = "${title}: ${clean_name}" }
      else { $full_title = $clean_name }

      my $node = $tree->{ $clean_sort } = { clean  => $clean_sort,
                                            name   => $clean_name,
                                            path   => $full_path,
                                            title  => $full_title,
                                            type   => 'file',
                                            url    => $url,
                                            _order => $index++, };

      if ($file->is_dir) {
         $node->{tree} = __get_tree( $full_path, $url, $full_title );
         $node->{type} = 'folder';
      }
   }

   return $tree;
}

sub __load_page {
   my ($tree, $path) = @_; my $branch = __find_branch( $tree, $path );

   ($branch and exists $branch->{type} and $branch->{type} eq 'file')
      or return { content => "Oh no. That page doesn't exist" };

   my $page = { content => io( $branch->{path} )->utf8->all };

   $branch->{name} ne 'index' and $page->{header} = $branch->{title};
   $page->{format} = 'markdown';
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

sub __to_array_of_hash {
   my ($href, $key_key, $val_key) = @_;

   return [ map { my $v = $href->{ $_ }; +{ $key_key => $_, $val_key => $v } }
            sort keys %{ $href } ],
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Doh::Model::Documentation - One-line description of the modules purpose

=head1 Synopsis

   use Doh::Model::Documentation;
   # Brief but working code examples

=head1 Version

This documents version v0.1.$Rev: 4 $ of L<Doh::Model::Documentation>

=head1 Description

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=back

=head1 Subroutines/Methods

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Usul>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2013 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE

=cut

# Local Variables:
# mode: perl
# tab-width: 3
# End:
