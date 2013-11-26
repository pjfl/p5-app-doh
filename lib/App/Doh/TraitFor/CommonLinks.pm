# @(#)Ident: CommonLinks.pm 2013-09-14 12:41 pjf ;

package App::Doh::TraitFor::CommonLinks;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 22 $ =~ /\d+/gmx );

use Moo::Role;

requires qw( config );

around 'get_stash' => sub {
   my ($orig, $self, $req) = @_; my $stash = $orig->( $self, $req );

   $stash->{links} = $self->_get_links( $req );
   return $stash;
};

sub _get_links {
   my ($self, $req) = @_; my $conf = $self->config; my $links = {};

   for (@{ $conf->common_links }) {
      $links->{ $_ } = $req->uri_for( $conf->$_() );
   }

   return $links;
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
