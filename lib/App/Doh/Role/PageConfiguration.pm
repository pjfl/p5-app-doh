package App::Doh::Role::PageConfiguration;

use namespace::autoclean;

use Class::Usul::Constants qw( FALSE NUL TRUE );
use Class::Usul::Types     qw( Object );
use Try::Tiny;
use Moo::Role;

requires qw( components config initialise_stash load_page log );

has 'users' => is => 'lazy', isa => Object,
   builder  => sub { $_[ 0 ]->components->{user} };

# Construction
around 'initialise_stash' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $stash  = $orig->( $self, $req, @args ); my $conf = $self->config;

   my $params = $req->query_params; my $sess = $req->session;

   for my $k (@{ $conf->stash_attr->{session} }) {
      try {
         my $v = $params->( $k, { optional => 1 } );

         $stash->{prefs}->{ $k } = defined $v ? $sess->$k( $v ) : $sess->$k();
      }
      catch { $self->log->warn( $_ ) };
   }

   $stash->{skin} = delete $stash->{prefs}->{skin};

   for my $k (@{ $conf->stash_attr->{links} }) {
      $stash->{links}->{ $k } = $req->uri_for( $conf->$k() );
   }

   $stash->{links}->{cdnjs   } = $conf->cdnjs; # TODO: Not a URI object ref
   $stash->{links}->{base_uri} = $req->base;
   $stash->{links}->{req_uri } = $req->uri;

   return $stash;
};

around 'load_page' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $page = $orig->( $self, $req, @args ); my $conf = $self->config;

   for my $k (@{ $conf->stash_attr->{request} }) { $page->{ $k }   = $req->$k  }

   for my $k (@{ $conf->stash_attr->{config } }) { $page->{ $k } //= $conf->$k }

   $page->{application_version} = $conf->appclass->VERSION;
   $page->{status_message     } = $req->session->collect_status_message( $req );

   my $url = $page->{mode} eq 'online' ? $req->base : $req->uri_for( 'index' );

   my $editing = $req->query_params->( 'edit', { optional => TRUE } ) // FALSE;

   $page->{homepage_url}   = $url;
   $page->{editing     } //= $editing;
   $page->{form_name   } //= 'markdown';
   $page->{hint        } //= $req->loc( 'Hint' );
   $page->{locale      } //= $req->locale;
   $page->{wanted      } //= join '/', @{ $req->uri_params->() // [] };

   $page->{editing} and $page->{user} = $self->users->find( $req->username );

   return $page;
};

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
