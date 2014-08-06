package App::Doh::Role::PageConfiguration;

use namespace::autoclean;

use App::Doh::Functions    qw( extract_lang );
use Class::Usul::Constants qw( FALSE NUL TRUE );
use Moo::Role;

requires qw( config load_page users );

# Construction
around 'load_page' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $page = $orig->( $self, $req, @args ); my $conf = $self->config;

   for (qw( author description keywords template )) {
      $page->{ $_ } //= $conf->$_();
   }

   $page->{application_version}   = $App::Doh::VERSION;
   $page->{editing            } //= $req->params->{edit} // FALSE;
   $page->{form_name          }   = 'markdown';
   $page->{hint               }   = $req->loc( 'Hint' );
   $page->{locale             } //= $req->locale;
   $page->{mode               }   = $req->params->{mode} // 'online';
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
