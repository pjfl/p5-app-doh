package App::Doh::View::JSON;

use namespace::autoclean;

use Moo;
use Class::Usul::Constants qw( FALSE );
use Class::Usul::Types     qw( Object );
use Encode                 qw( encode );
use JSON::MaybeXS          qw( );

with q(App::Doh::Role::Component);
with q(App::Doh::Role::Templates);

# Public attributes
has '+moniker' => default => 'json';

# Private attributes
has '_transcoder' => is => 'lazy', isa => Object,
   builder        => sub { JSON::MaybeXS->new( utf8 => FALSE ) };

# Private functions
my $_header = sub {
   return [ 'Content-Type' => 'application/json', @{ $_[ 0 ] // [] } ];
};

# Public methods
sub serialize {
   my ($self, $req, $stash) = @_;

   my $meta    = $stash->{page}->{meta} // {};
   my $js      = join "\n", @{ $stash->{page}->{literal_js} // [] };
   my $content = { html => $self->render_template( $req, $stash ) };

   $content->{ $_ } = $meta->{ $_ } for (keys %{ $meta });

   $js and $content->{script} = $js;
   $content = encode( $self->encoding, $self->_transcoder->encode( $content ) );

   return [ $stash->{code}, $_header->( $stash->{http_headers} ), [ $content ]];
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
