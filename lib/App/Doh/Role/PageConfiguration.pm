package App::Doh::Role::PageConfiguration;

use namespace::autoclean;

use Class::Usul::Constants qw( TRUE );
use Try::Tiny;
use Moo::Role;

requires qw( config initialise_stash load_page log );

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

   my $links = $stash->{links} //= {};

   for my $k (@{ $conf->stash_attr->{links} }) {
      $links->{ $k } = $req->uri_for( $conf->$k().'/' );
   }

   $links->{cdnjs   } = $conf->cdnjs; # TODO: Not a URI object ref
   $links->{base_uri} = $req->base;
   $links->{req_uri } = $req->uri;
   $links->{edit_uri} = $req->uri_for( $req->path, [], edit => TRUE );

   return $stash;
};

around 'load_page' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $page = $orig->( $self, $req, @args ); my $conf = $self->config;

   for my $k (@{ $conf->stash_attr->{request} }) { $page->{ $k }   = $req->$k  }

   for my $k (@{ $conf->stash_attr->{config } }) { $page->{ $k } //= $conf->$k }

   $page->{application_version} = $conf->appclass->VERSION;
   $page->{status_message     } = $req->session->collect_status_message( $req );

   $page->{form_name} //= 'markdown';
   $page->{hint     } //= $req->loc( 'Hint' );
   $page->{wanted   } //= join '/', @{ $req->uri_params->() // [] };

   return $page;
};

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
