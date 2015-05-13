package App::Doh::Role::Preferences;

use namespace::autoclean;

use Try::Tiny;
use Moo::Role;

requires qw( config initialise_stash log );

around 'initialise_stash' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $stash  = $orig->( $self, $req, @args );
   my $params = $req->query_params;
   my $sess   = $req->session;
   my $conf   = $self->config;

   for my $k (@{ $conf->preferences }) {
      my $v = $params->( $k, { optional => 1 }) // $sess->{ $k } // $conf->$k();

      try   { $stash->{prefs}->{ $k } = $sess->$k( $v ) }
      catch { $self->log->warn( $_ ) };
   }

   return $stash;
};

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
