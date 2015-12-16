package App::Doh::Role::PageLoading;

use namespace::autoclean;

use App::Doh::Util         qw( build_navigation clone mtime );
use Class::Usul::Constants qw( FALSE NUL TRUE );
use Class::Usul::Functions qw( throw );
use Class::Usul::Types     qw( HashRef );
use HTTP::Status           qw( HTTP_NOT_FOUND );
use Moo::Role;

requires qw( config load_page localised_tree );

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

      my $node = $self->find_node( $locale, $req->uri_params->() ) or next;
      my $page = $self->initialise_page( $req, $node, $locale );

      return $orig->( $self, $req, $page );
   }

   return $orig->( $self, $req, $self->not_found( $req ) );
};

# Public methods
sub find_node {
   my ($self, $locale, $ids) = @_;

   my $node = $self->localised_tree( $locale ) or return FALSE;

   $ids //= []; $ids->[ 0 ] //= 'index';

   for my $node_id (@{ $ids }) {
      $node->{type} eq 'folder' and $node = $node->{tree};
      exists  $node->{ $node_id } or return FALSE;
      $node = $node->{ $node_id };
   }

   return $node;
}

sub initialise_page {
   my ($self, $req, $node, $locale) = @_; my $page = clone $node;

   $page->{content} = delete $page->{path}; $page->{locale} = $locale;

   return $page;
}

{  my $cache //= {};

   sub invalidate_cache {
      my ($self, $mtime) = @_; my $file = $self->config->root_mtime;

      $cache = {}; $self->log->debug( 'Cache invalidated' );

      if ($mtime) { $file->touch( $mtime ) }
      else { $file->exists and $file->unlink }

      return;
   }

   sub navigation {
      my ($self, $req, $stash) = @_;

      my $conf   = $self->config;
      my $locale = $conf->locale; # Always index config default language
      my $node   = $self->localised_tree( $locale )
         or  throw 'Default locale [_1] has no document tree', [ $locale ],
                   rv => HTTP_NOT_FOUND;
      my $ids    = $req->uri_params->() // [];
      my $wanted = $stash->{page}->{wanted} // NUL;
      my $nav    = $cache->{ $wanted };

      (not $nav or mtime $node > $nav->{mtime})
         and $nav = $cache->{ $wanted }
            = { list  => build_navigation( $conf, $node, $ids, $wanted ),
                mtime => mtime( $node ), };

      return $nav->{list};
   }
}

sub not_found {
   my ($self, $req) = @_;

   my $rv      = HTTP_NOT_FOUND;
   my $name    = $req->loc( 'Not Found' );
   my $content = '##### '.$req->loc( 'Page [_1] not found', $req->uri )
                 ."\n\n    Code: ${rv}\n\n";

   return { content => $content,
            format  => 'markdown',
            mtime   => time,
            name    => $name,
            title   => ucfirst $name, };
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
