package App::Doh::Role::PageConfiguration;

use namespace::autoclean;

use App::Doh::Functions    qw( extract_lang );
use Class::Usul::Constants qw( FALSE NUL );
use Moo::Role;

requires qw( config load_page );

# Construction
around 'load_page' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $page = $orig->( $self, $req, @args ); my $conf = $self->config;

   $page->{ $_ } //= $conf->$_() for (qw( author description keywords ));

   $page->{form_name          }   = 'markdown';
   $page->{locale             } //= $req->locale;
   $page->{wanted             } //= join '/', @{ $req->args };
   $page->{application_version}   = $App::Doh::VERSION;
   $page->{editing            } //= $req->params->{edit} // FALSE;
   $page->{language           }   = extract_lang $page->{locale};
   $page->{mode               }   = $req->params->{mode} // 'online';
   $page->{status_message     }   = $req->session->clear_status_message;
   $page->{homepage_url       }   = $page->{mode} eq 'online'
                                  ? $req->base : $req->uri_for( 'index' );

   return $page;
};

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
