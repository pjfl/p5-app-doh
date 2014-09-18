package App::Doh::Role::PageConfiguration;

use namespace::autoclean;

use App::Doh::Functions    qw( extract_lang );
use Class::Usul::Constants qw( FALSE NUL TRUE );
use Moo::Role;

requires qw( config load_page users );

# Construction
around 'load_page' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $conf    = $self->config; my $page = $orig->( $self, $req, @args );

   my $editing = $req->query_params->( 'edit', { optional => TRUE } ) // FALSE;

   for (qw( author description keywords template )) {
      $page->{ $_ } //= $conf->$_();
   }

   $page->{application_version}   = $App::Doh::VERSION;
   $page->{editing            } //= $editing;
   $page->{form_name          }   = 'markdown';
   $page->{hint               }   = $req->loc( 'Hint' );
   $page->{locale             } //= $req->locale;
   $page->{mode               }   = $req->mode;
   $page->{status_message     }   = $req->session->clear_status_message( $req );
   $page->{wanted             } //= join '/', @{ $req->args };
   $page->{homepage_url       }   = $page->{mode} eq 'online'
                                  ? $req->base : $req->uri_for( 'index' );
   $page->{language           }   = extract_lang $page->{locale};

   $page->{editing} and $page->{user} = $self->users->find( $req->username );

   return $page;
};

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
