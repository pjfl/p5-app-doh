package App::Doh::Role::Preferences;

use namespace::autoclean;

use Moo::Role;

requires qw( config get_stash );

around 'get_stash' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $stash  = $orig->( $self, $req, @args );
   my $params = $req->params;
   my $sess   = $req->session;
   my $conf   = $self->config;

   for my $k (@{ $conf->preferences }) {
      my $v = $params->{ $k } // $sess->{ $k } // $conf->$k();

      $stash->{prefs}->{ $k } = $sess->$k( $v );
   }

   return $stash;
};

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
