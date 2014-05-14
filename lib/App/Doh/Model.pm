package App::Doh::Model;

use namespace::sweep;

use Moo;
use App::Doh::Functions qw( show_node );
use Class::Usul::Constants;
use Class::Usul::Time   qw( str2time time2str );
use Class::Usul::Types  qw( HashRef );
use HTTP::Status        qw( HTTP_BAD_REQUEST HTTP_OK );
use Scalar::Util        qw( weaken );

extends q(App::Doh);

has 'type_map' => is => 'lazy', isa => HashRef, builder => sub { {} };

sub exception_handler {
   my ($self, $req, $e) = @_;

   my $stash  = $self->get_stash( $req );
   my $header = $req->loc( 'Exception Handler' );
   my $filler = '&nbsp;' x 40;

   $stash->{code} =  $e->rv >= HTTP_OK ? $e->rv : HTTP_BAD_REQUEST;
   $stash->{page} =  $self->load_page( $req, {
      content     => "${e}${filler}\n\n   Code: ".$e->rv,
      format      => 'markdown',
      header      => $header,
      mtime       => time,
      title       => $header, } );
   $stash->{nav } =  $self->navigation( $req, $stash );

   return $stash;
}

sub execute {
   my ($self, $method, @args) = @_; return $self->$method( @args );
}

sub get_content {
   my ($self, $req) = @_; my $stash = $self->get_stash( $req );

   $stash->{page} = $self->load_page ( $req );
   $stash->{nav } = $self->navigation( $req, $stash );

   return $stash;
}

sub get_stash {
   my ($self, $req) = @_; weaken( $req );

   return { code      => HTTP_OK,
            loc       => sub { $req->loc( @_ ) },
            req       => $req,
            show_node => \&show_node,
            str2time  => \&str2time,
            time2str  => \&time2str,
            uri_for   => sub { $req->uri_for( @_ ) }, };
}

sub load_page {
   my ($self, $req, $args) = @_; my $page = $args // {}; return $page;
}

sub navigation {
   return [ { depth => 0, name => 'Home', type => 'file', url => NUL } ];
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
