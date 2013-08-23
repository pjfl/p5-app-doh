# @(#)Ident: Preferences.pm 2013-08-22 23:19 pjf ;

package Doh::TraitFor::Preferences;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 19 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Functions  qw( base64_decode_ns );
use Storable                qw( thaw );
use Moo::Role;

requires qw( config );

around 'get_stash' => sub {
   my ($orig, $self, $req) = @_; my $stash = $orig->( $self, $req );

   $stash->{prefs} = $self->_get_preferences( $req );
   return $stash;
};

sub _get_preferences {
   my ($self, $req) = @_; my $conf = $self->config; my $r = {};

   my $cookie = $req->cookie->{ $conf->name.'_prefs' };
   my $frozen = base64_decode_ns( $cookie ? $cookie->value : FALSE );
   my $prefs  = $frozen ? thaw $frozen : {};

   for my $k (@{ $conf->preferences }) {
      $r->{ $k } = $req->params->{ $k } // $prefs->{ $k } // $conf->$k();
   }

   return $r;
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
