package App::Doh::Role::PageLoading;

use namespace::sweep;

use App::Doh::Functions    qw( build_navigation_list mtime );
use Class::Usul::Constants;
use Class::Usul::Functions qw( throw );
use HTTP::Status           qw( HTTP_NOT_FOUND );
use Moo::Role;

requires qw( config get_stash load_page localised_tree root_mtime );

# Public methods
sub content_from_file {
   return $_[ 0 ]->get_stash( $_[ 1 ], $_[ 0 ]->load_page( $_[ 1 ] ) );
}

sub find_node {
   my ($self, $locale, $ids) = @_;

   my $node = $self->localised_tree( $locale ) or return FALSE;

   $ids //= []; $ids->[ 0 ] or $ids->[ 0 ] = 'index';

   for my $node_id (@{ $ids }) {
      $node->{type} eq 'folder' and $node = $node->{tree};
      exists  $node->{ $node_id } or return FALSE;
      $node = $node->{ $node_id };
   }

   return $node;
}

sub load_localised_page {
   my ($self, $orig, $req, @args) = @_; my $conf = $self->config;

   $args[ 0 ] and return $orig->( $self, $req, $args[ 0 ] );

   for my $locale ($req->locale, @{ $req->locales }, $conf->locale) {
      my $node = $self->find_node( $locale, [ @{ $req->args } ] );

      ($node and $node->{type} ne 'folder') or next;

      return $orig->( $self, $req, $self->make_page( $node, $req, $locale ) );
   }

   return $orig->( $self, $req, $self->not_found( $req ) );
}

{  my $cache //= {};

   sub invalidate_cache {
      my ($self, $mtime) = @_; $cache = {};

      $self->root_mtime->touch( $mtime );
      return;
   }

   sub navigation {
      my ($self, $req, $page) = @_;

      my $locale = $self->config->locale; # Always index config default language
      my $root   = $self->config->file_root;
      my $node   = $self->localised_tree( $locale )
         or throw error => 'No document tree for default locale [_1]',
                   args => [ $locale ], rv => HTTP_NOT_FOUND;
      my $wanted = $page->{wanted};
      my @ids    = @{ $req->args };
      my $nav    = $cache->{ $wanted };

      (not $nav or mtime $node > $nav->{mtime})
         and $nav = $cache->{ $wanted }
            = { list  => build_navigation_list( $root, $node, \@ids, $wanted ),
                mtime => mtime( $node ), };

      return $nav->{list};
   }
}

sub make_page {
   return { content  => $_[ 1 ]->{path  },
            format   => $_[ 1 ]->{format},
            header   => $_[ 1 ]->{title },
            meta     => $_[ 1 ]->{meta  },
            mtime    => $_[ 1 ]->{mtime },
            title    => ucfirst $_[ 1 ]->{name},
            url      => $_[ 1 ]->{url   }, };
}

sub not_found {
   my ($self, $req) = @_;

   my $rv      = HTTP_NOT_FOUND;
   my $title   = $req->loc( 'Not found' );
   my $content = '> '.$req->loc( "Oh no. That page doesn't exist" )
                 ."\n\n    Code: ${rv}\n\n";

   return { content  => $content,
            format   => 'markdown',
            header   => $title,
            mtime    => time,
            title    => $title, };
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::Doh::Role::PageLoading - One-line description of the modules purpose

=head1 Synopsis

   use App::Doh::Role::PageLoading;
   # Brief but working code examples

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

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-Doh.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2014 Peter Flanigan. All rights reserved

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
# vim: expandtab shiftwidth=3:
