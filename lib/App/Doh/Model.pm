package App::Doh::Model;

use namespace::sweep;

use Moo;
use Class::Usul::Time qw( time2str );
use HTTP::Status      qw( HTTP_OK );
use Scalar::Util      qw( weaken );

extends q(App::Doh);

sub get_stash {
   my ($self, $req, $page) = @_; weaken( $req );

   return { code     => HTTP_OK,
            loc      => sub { $req->loc( @_ ) },
            page     => $page,
            req      => $req,
            time2str => sub { time2str( $_[ 0 ], $_[ 1 ], $_[ 2 ] ) },
            uri_for  => sub { $req->uri_for( @_ ) }, };
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
