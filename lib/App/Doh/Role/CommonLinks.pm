package App::Doh::Role::CommonLinks;

use namespace::autoclean;

use Moo::Role;

requires qw( config initialise_stash );

around 'initialise_stash' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $stash = $orig->( $self, $req, @args ); my $conf = $self->config;

   $stash->{links}->{cdnjs   } = $conf->cdnjs;
   $stash->{links}->{base_uri} = $req->base;
   $stash->{links}->{req_uri } = $req->uri;

   for (@{ $conf->common_links }) {
      $stash->{links}->{ $_ } = $req->uri_for( $conf->$_() );
   }

   return $stash;
};

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
