package App::Doh::Role::PageConfiguration;

use namespace::sweep;

use Class::Usul::Constants;
use Moo::Role;

requires qw( config load_page );

# Construction
around 'load_page' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $page = $orig->( $self, $req, @args ); my $conf = $self->config;

   $page->{ $_ } = $conf->$_() for (qw( author description keywords ));

   $page->{application_version} = $App::Doh::VERSION;
   $page->{editing            } = $req->params->{edit} // FALSE;
   $page->{homepage_url       } = $req->base;
   $page->{language           } = (split m{ _ }mx, $req->locale)[ 0 ];
   $page->{mode               } = $req->params->{mode} // 'online';
   $page->{status_message     } = delete $req->session->{status_message} // NUL;

   return $page;
};

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
