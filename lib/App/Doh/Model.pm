package App::Doh::Model;

use App::Doh::Attributes;  # Will do cleaning
use App::Doh::Functions    qw( show_node );
use Class::Usul::Constants qw( FALSE NUL );
use Class::Usul::Functions qw( is_member );
use Class::Usul::Time      qw( str2time time2str );
use HTTP::Status           qw( HTTP_BAD_REQUEST HTTP_OK );
use Scalar::Util           qw( blessed weaken );
use Moo;

with q(App::Doh::Role::Component);

# Public methods
sub exception_handler {
   my ($self, $req, $e) = @_;

   my $stash  = $self->initialise_stash( $req );
   my $title  = $req->loc( 'Exception Handler' );
   my $errors = '&nbsp;' x 40;  $e->args->[ 0 ] and blessed $e->args->[ 0 ]
      and $errors = "\n\n".( join "\n\n", map { "${_}" } @{ $e->args } );

   $stash->{code} =  $e->rv >= HTTP_OK ? $e->rv : HTTP_BAD_REQUEST;
   $stash->{page} =  $self->load_page( $req, {
      content     => "${e}${errors}\n\n   Code: ".$e->rv,
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
   my ($self, $req) = @_; my $stash = $self->initialise_stash( $req );

   $stash->{page} = $self->load_page ( $req );
   $stash->{nav } = $self->navigation( $req, $stash );

   return $stash;
}

sub initialise_stash {
   my ($self, $req) = @_; weaken( $req );

   return { code         => HTTP_OK,
            functions    => {
               is_member => \&is_member,
               loc       => sub { $req->loc( @_ ) },
               show_node => \&show_node,
               str2time  => \&str2time,
               time2str  => \&time2str,
               ucfirst   => sub { ucfirst $_[ 0 ] },
               uri_for   => sub { $req->uri_for( @_ ), }, },
            req          => $req,
            view         => $self->config->default_view, };
}

sub load_page {
   my ($self, $req, $args) = @_; my $page = $args // {}; return $page;
}

sub navigation {
   return [ { depth => 0, title => 'Home', type => 'file', url => NUL } ];
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
