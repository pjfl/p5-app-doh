package App::Doh::Role::PageConfiguration;

use namespace::autoclean;

use Class::Usul::Constants qw( FALSE NUL TRUE );
use Class::Usul::Types     qw( Object );
use Moo::Role;

requires qw( components config load_page );

has 'users' => is => 'lazy', isa => Object,
   builder  => sub { $_[ 0 ]->components->{user} };

# Construction
around 'load_page' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $page = $orig->( $self, $req, @args ); my $conf = $self->config;

   for my $k (qw( author description keywords template )) {
      $page->{ $k } //= $conf->$k();
   }

   $page->{application_version} = $App::Doh::VERSION;
   $page->{status_message     } = $req->session->collect_status_message( $req );

   my $editing = $req->query_params->( 'edit', { optional => TRUE } ) // FALSE;

   $page->{editing     } //= $editing;
   $page->{form_name   } //= 'markdown';
   $page->{locale      } //= $req->locale;
   $page->{wanted      } //= join '/', @{ $req->uri_params->() // [] };
   $page->{homepage_url}   = $page->{mode} eq 'online'
                           ? $req->base : $req->uri_for( 'index' );

   $page->{editing} and $page->{user} = $self->users->find( $page->{username} );

   return $page;
};

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
