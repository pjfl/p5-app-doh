package App::Doh::Model;

use Moo;
use App::Doh::Attributes;
use App::Doh::Functions    qw( show_node );
use App::Doh::User;
use Class::Usul::Constants qw( FALSE NUL );
use Class::Usul::Functions qw( is_member );
use Class::Usul::IPC;
use Class::Usul::Time      qw( str2time time2str );
use Class::Usul::Types     qw( Object );
use HTTP::Status           qw( HTTP_BAD_REQUEST HTTP_OK );
use Scalar::Util           qw( weaken );

extends q(App::Doh);

# Public attributes
has 'ipc'   => is => 'lazy', isa => Object, builder  => sub {
   Class::Usul::IPC->new( builder => $_[ 0 ]->usul ) };

has 'users' => is => 'lazy', isa => Object, builder => sub {
   App::Doh::User->new( builder => $_[ 0 ]->usul ) };

sub exception_handler {
   my ($self, $req, $e) = @_;

   my $stash  = $self->get_stash( $req );
   my $title  = $req->loc( 'Exception Handler' );
   my $filler = '&nbsp;' x 40;

   $stash->{code} =  $e->rv >= HTTP_OK ? $e->rv : HTTP_BAD_REQUEST;
   $stash->{page} =  $self->load_page( $req, {
      content     => "${e}${filler}\n\n   Code: ".$e->rv,
      editing     => FALSE,
      format      => 'markdown',
      mtime       => time,
      name        => $title,
      title       => $title,
      type        => 'generated' } );
   $stash->{nav } =  $self->navigation( $req, $stash );

   return $stash;
}

sub execute {
   my ($self, $method, @args) = @_; return $self->$method( @args );
}

sub get_content : Role(any) {
   my ($self, $req) = @_; my $stash = $self->get_stash( $req );

   $stash->{page} = $self->load_page ( $req );
   $stash->{nav } = $self->navigation( $req, $stash );

   return $stash;
}

sub get_stash {
   my ($self, $req) = @_; weaken( $req );

   return { code      => HTTP_OK,
            is_member => \&is_member,
            loc       => sub { $req->loc( @_ ) },
            req       => $req,
            show_node => \&show_node,
            str2time  => \&str2time,
            time2str  => \&time2str,
            ucfirst   => sub { ucfirst $_[ 0 ] },
            uri_for   => sub { $req->uri_for( @_ ) },
            view      => $self->config->default_view, };
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
