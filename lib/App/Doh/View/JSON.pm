package App::Doh::View::JSON;

use namespace::autoclean;

use App::Doh::Util         qw( stash_functions );
use Class::Usul::Constants qw( FALSE );
use Class::Usul::Types     qw( CodeRef Object );
use Encode                 qw( encode );
use JSON::MaybeXS          qw( );
use Moo;

with 'Web::Components::Role';
with 'Web::Components::Role::TT';

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
   my ($self, $req, $stash) = @_; stash_functions $self, $req, $stash;

   my $content = defined $stash->{content} ? $stash->{content}
               : { html => $self->render_template( $stash ) };
   my $meta    = $stash->{page}->{meta} // {};

   $content->{ $_ } = $meta->{ $_ } for (keys %{ $meta });

   my $js; $js = join "\n", @{ $stash->{page}->{literal_js} // [] }
      and $content->{script} = $js;

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
