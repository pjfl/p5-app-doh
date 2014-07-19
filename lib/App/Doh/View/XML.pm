package App::Doh::View::XML;

use namespace::autoclean;

use Moo;
use Class::Usul::Constants qw( TRUE );
use Class::Usul::Types     qw( Object );
use Encode                 qw( encode );
use XML::Simple;

extends q(App::Doh);
with    q(App::Doh::Role::Templates);

# Public attributes
has '+moniker'   => default => 'xml';

# Private attributes
has '_transcoder' => is => 'lazy', isa => Object,
   builder        => sub { XML::Simple->new };

# Public methods
sub serialize {
   my ($self, $req, $stash) = @_; $stash->{content_only} = TRUE;

   my $content = { items => [ $self->render_template( $req, $stash ) ] };
   my $js      = join "\n", @{ $stash->{page}->{literal_js} // [] };
   my $meta    = $stash->{page}->{meta} // {};

   $content->{ $_ } = $meta->{ $_ } for (keys %{ $meta });

   $js and $content->{script} //= [] and push @{ $content->{script} }, $js;
   $content = encode( 'UTF-8', $self->_transcoder->xml_out( $content ) );

   return [ $stash->{code}, __header( $stash->{http_headers} ), [ $content ] ];
}

# Private functions
sub __header {
   return [ 'Content-Type' => 'text/xml', @{ $_[ 0 ] // [] } ];
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
