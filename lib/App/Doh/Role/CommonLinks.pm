package App::Doh::Role::CommonLinks;

use namespace::sweep;

use Moo::Role;

requires qw( config get_stash );

around 'get_stash' => sub {
   my ($orig, $self, $req) = @_; my $stash = $orig->( $self, $req );

   my $conf = $self->config; $stash->{links}->{req_uri} = $req->uri;

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
