package App::Doh::Role::PageConfiguration;

use namespace::sweep;

use Class::Usul::Constants;
use Moo::Role;

requires qw( config load_page );

# Construction
around 'load_page' => sub {
   my ($orig, $self, $req) = @_; my $page = $orig->( $self, $req );

   my $conf = $self->config;

   $page->{ $_ } = $conf->$_() for (qw( author description keywords ));

   $page->{application_version} = $App::Doh::VERSION;
   $page->{status_message     } = delete $req->session->{status_message} // NUL;
   return $page;
};

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
