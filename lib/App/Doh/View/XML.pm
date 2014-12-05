package App::Doh::View::XML;

use namespace::autoclean;

use Moo;
use Class::Usul::Constants qw( TRUE );
use Class::Usul::Types     qw( Object );
use Encode                 qw( encode );
use XML::Simple;

with q(App::Doh::Role::Component);
with q(App::Doh::Role::Templates);

# Public attributes
has '+moniker'   => default => 'xml';

# Private attributes
has '_transcoder' => is => 'lazy', isa => Object,
   builder        => sub { XML::Simple->new };

# Private functions
my $_header = sub {
   return [ 'Content-Type' => 'text/xml', @{ $_[ 0 ] // [] } ];
};

# Public methods
sub serialize {
   my ($self, $req, $stash) = @_;

   my $content = { items => [ $self->render_template( $req, $stash ) ] };
   my $js      = join "\n", @{ $stash->{page}->{literal_js} // [] };
   my $meta    = $stash->{page}->{meta} // {};
   my $enc     = $self->encoding;

   $content->{ $_ } = $meta->{ $_ } for (keys %{ $meta });

   $js and $content->{script} //= [] and push @{ $content->{script} }, $js;
   $content = encode( $enc, $self->_transcoder->xml_out( $content ) );

   return [ $stash->{code}, $_header->( $stash->{http_headers} ), [ $content ]];
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
