package App::Doh::Role::PageLoading;

use namespace::autoclean;

use App::Doh::Util         qw( build_navigation clone mtime );
use Class::Usul::Constants qw( FALSE NUL TRUE );
use Class::Usul::File;
use Class::Usul::Functions qw( throw );
use Class::Usul::Types     qw( HashRef );
use HTTP::Status           qw( HTTP_NOT_FOUND );
use Moo::Role;

requires qw( config initialise_stash load_page localised_tree );

has 'type_map' => is => 'ro', isa => HashRef, builder => sub { {} };

# Private class attributes
my $_docs_cache = {};
my $_site_data_cache = { _mtime => 0 };

# Private functions
my $_cache_mtime_file = sub {
   return $_[ 0 ]->catfile( '.mtime' );
};

# Private methods
my $_load_site_data = sub {
   my $self = shift; my $site_data = $self->config->site_data;

   ($site_data->exists and $site_data->is_dir) or return {};

   my $filesys = $_cache_mtime_file->( $site_data );
   my $mtime   = $filesys->exists ? $filesys->stat->{mtime} // 0 : 0;

   if ($mtime == 0 or $mtime > $_site_data_cache->{_mtime}) {
      my $max_mtime = 0; my $no_dot_files = sub { not m{  \.mtime \z }mx };

      for my $file ($site_data->filter( $no_dot_files )->all_files) {
         (my $name = $file->basename) =~ s{ \. [a-zA-Z0-9_]+ \z }{}mx;

         $_site_data_cache->{data}->{ $name }
            = Class::Usul::File->data_load( paths => [ $file ] ) // {};
         $mtime = $file->stat->{mtime};
         $mtime > $max_mtime and $max_mtime = $mtime;
      }

      $filesys->touch( $_site_data_cache->{_mtime} = $max_mtime );
   }

   return $_site_data_cache->{data} // {};
};

my $_update_filesys = sub {
   my ($self, $text, $file, $mtime) = @_;

   if ($mtime) { $file->touch( $mtime ) }
   else { $file->exists and $file->unlink }

   $self->log->debug( $text );

   return;
};

# Construction
around 'BUILDARGS' => sub {
   my ($orig, $self, @args) = @_; my $attr = $orig->( $self, @args );

   my $views = $attr->{views} or return $attr;

   exists $views->{html} and $attr->{type_map} = $views->{html}->type_map;

   return $attr;
};

around 'initialise_stash' => sub {
   my ($orig, $self, @args) = @_; my $stash = $orig->( $self, @args );

   $stash->{site} = $self->$_load_site_data;

   return $stash;
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

sub invalidate_docs_cache {
   my ($self, $mtime) = @_; $_docs_cache = {};

   my $filesys = $self->config->root_mtime;

   $self->$_update_filesys( 'Document cache invalidated', $filesys, $mtime );

   return;
}

# TODO: Work out where / how to call this
sub invalidate_site_data_cache {
   my ($self, $mtime) = @_; $_site_data_cache = { _mtime => 0 };

   my $filesys = $_cache_mtime_file->( $self->config->site_data );

   $self->$_update_filesys( 'Site data cache invalidated', $filesys, $mtime );

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
   my $tuple  = $_docs_cache->{ $wanted };

   (not $tuple or mtime $node > $tuple->{mtime})
    and $tuple = $_docs_cache->{ $wanted }
               = { list  => build_navigation( $conf, $node, $ids, $wanted ),
                   mtime => mtime( $node ), };

   return $tuple->{list};
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
