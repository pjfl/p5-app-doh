package App::Doh::Model;

use namespace::sweep;

use Moo;
use Class::Usul::Constants;
use Class::Usul::Time qw( time2str );
use HTTP::Status      qw( HTTP_OK );
use Scalar::Util      qw( weaken );

extends q(App::Doh);

sub exception_handler {
   my ($self, $req, $e) = @_;

   my $title = $req->loc( 'Exception Handler' );
   my $page  = $self->load_page( $req, {
      content  => "${e}  \n   Code: ".$e->rv,
      docs_url => $req->uri_for( $self->_docs_url( $req->locale ) ),
      format   => 'markdown',
      header   => $title,
      mtime    => time,
      title    => $title, } );
   my $stash = $self->get_stash( $req, $page );

   $stash->{nav     } = $self->navigation( $req );
   $stash->{template} = 'documentation';
   return $stash;
}

sub execute {
   my ($self, $method, $req) = @_; return $self->$method( $req );
}

sub get_stash {
   my ($self, $req, $page) = @_; weaken( $req );

   return { code     => HTTP_OK,
            loc      => sub { $req->loc( @_ ) },
            page     => $page,
            req      => $req,
            time2str => sub { time2str( $_[ 0 ], $_[ 1 ], $_[ 2 ] ) },
            uri_for  => sub { $req->uri_for( @_ ) }, };
}

sub load_page {
   my ($self, $req, $args) = @_; my $page = $args // {}; return $page;
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
