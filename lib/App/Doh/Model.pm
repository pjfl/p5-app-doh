package App::Doh::Model;

use namespace::sweep;

use Moo;
use Class::Usul::Constants;
use Class::Usul::Time  qw( time2str );
use Class::Usul::Types qw( HashRef );
use HTTP::Status       qw( HTTP_BAD_REQUEST HTTP_OK );
use Scalar::Util       qw( weaken );

extends q(App::Doh);

has 'type_map' => is => 'lazy', isa => HashRef, builder => sub { {} };

sub exception_handler {
   my ($self, $req, $e) = @_;

   my $title   =  $req->loc( 'Exception Handler' );
   my $filler  =  '&nbsp;' x 40;
   my $page    =  {
      content  => "${e}${filler}\n\n   Code: ".$e->rv,
      format   => 'markdown',
      header   => $title,
      mtime    => time,
      title    => $title, };
   my $stash   =  $self->get_stash( $req, $self->load_page( $req, $page ) );

   $stash->{code} = $e->rv >= HTTP_OK ? $e->rv : HTTP_BAD_REQUEST;

   return $stash;
}

sub execute {
   my ($self, $method, $req) = @_; return $self->$method( $req );
}

sub get_stash {
   my ($self, $req, $page) = @_; weaken( $req );

   return { code     => HTTP_OK,
            loc      => sub { $req->loc( @_ ) },
            nav      => $self->navigation( $req, $page ),
            page     => $page,
            req      => $req,
            time2str => sub { time2str( $_[ 0 ], $_[ 1 ], $_[ 2 ] ) },
            uri_for  => sub { $req->uri_for( @_ ) }, };
}

sub load_page {
   my ($self, $req, $args) = @_; my $page = $args // {}; return $page;
}

sub navigation {
   return [ { level => 0, name => 'Home', type => 'file', url => NUL } ];
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
