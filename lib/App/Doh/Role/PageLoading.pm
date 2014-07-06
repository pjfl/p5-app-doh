package App::Doh::Role::PageLoading;

use namespace::autoclean;

use App::Doh::Functions    qw( build_navigation_list clone mtime );
use Class::Usul::Constants qw( FALSE NUL TRUE );
use Class::Usul::Functions qw( throw );
use Class::Usul::Types     qw( HashRef );
use HTTP::Status           qw( HTTP_NOT_FOUND );
use Moo::Role;

requires qw( config get_stash load_page localised_tree );

has 'type_map' => is => 'lazy', isa => HashRef, builder => sub { {} };

# Construction
around 'BUILDARGS' => sub {
   my ($orig, $self, @args) = @_; my $attr = $orig->( $self, @args );

   my $views = $attr->{views} or return $attr;

   for my $view (values %{ $views }) {
      $view->can( 'type_map' ) and $attr->{type_map} = $view->type_map and last;
   }

   return $attr;
};

around 'load_page' => sub {
   my ($orig, $self, $req, @args) = @_; my %seen = ();

   $args[ 0 ] and return $orig->( $self, $req, $args[ 0 ] );

   for my $locale ($req->locale, @{ $req->locales }, $self->config->locale) {
      $seen{ $locale } and next; $seen{ $locale } = TRUE;

      my $node = $self->find_node( $locale, $req->args ) or next;

      return $orig->( $self, $req, $self->get_page( $req, $node, $locale ) );
   }

   return $orig->( $self, $req, $self->not_found( $req ) );
};

# Public methods
sub find_node {
   my ($self, $locale, $args) = @_;

   my $node = $self->localised_tree( $locale ) or return FALSE;
   my $ids  = [ @{ $args } ]; $ids->[ 0 ] or $ids->[ 0 ] = 'index';

   for my $node_id (@{ $ids }) {
      $node->{type} eq 'folder' and $node = $node->{tree};
      exists  $node->{ $node_id } or return FALSE;
      $node = $node->{ $node_id };
   }

   return $node;
}

sub get_page {
   my ($self, $req, $node, $locale) = @_; my $page = clone $node;

   $page->{content} = delete $page->{path}; $page->{locale} = $locale;

   return $page;
}

{  my $cache //= {};

   sub invalidate_cache {
      my ($self, $mtime) = @_; $cache = {};

      $self->log->debug( 'Cache invalidated' );
      $self->config->root_mtime->touch( $mtime );
      return;
   }

   sub navigation {
      my ($self, $req, $stash) = @_;

      my @ids    = @{ $req->args };
      my $locale = $self->config->locale; # Always index config default language
      my $root   = $self->config->file_root;
      my $node   = $self->localised_tree( $locale )
         or throw error => 'No document tree for default locale [_1]',
                   args => [ $locale ], rv => HTTP_NOT_FOUND;
      my $wanted = $stash->{page}->{wanted} // NUL;
      my $nav    = $cache->{ $wanted };

      (not $nav or mtime $node > $nav->{mtime})
         and $nav = $cache->{ $wanted }
            = { list  => build_navigation_list( $root, $node, \@ids, $wanted ),
                mtime => mtime( $node ), };

      return $nav->{list};
   }
}

sub not_found {
   my ($self, $req) = @_;

   my $rv      = HTTP_NOT_FOUND;
   my $title   = $req->loc( 'Not found' );
   my $content = '> '.$req->loc( "Oh no. That page doesn't exist" )
                 ."\n\n    Code: ${rv}\n\n";

   return { content => $content,
            format  => 'markdown',
            mtime   => time,
            name    => $title,
            title   => $title, };
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
