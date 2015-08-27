package App::Doh::Model;

use App::Doh::Attributes;  # Will do cleaning
use Class::Usul::Constants qw( FALSE NUL TRUE );
use Class::Usul::Functions qw( throw );
use Class::Usul::IPC;
use Class::Usul::Types     qw( Plinth ProcCommer );
use HTTP::Status           qw( HTTP_BAD_REQUEST HTTP_OK );
use Scalar::Util           qw( blessed );
use Moo;

with q(Web::Components::Role);

# Public attributes
has 'application' => is => 'ro', isa => Plinth,
   required       => TRUE,  weak_ref => TRUE;

# Private attributes
has '_ipc' => is => 'lazy', isa => ProcCommer, handles => [ 'run_cmd' ],
   builder => sub { Class::Usul::IPC->new( builder => $_[ 0 ]->application ) };

# Public methods
sub exception_handler {
   my ($self, $req, $e) = @_;

   my $title  =  $req->loc( 'Exception Handler' );
   my $errors =  '&nbsp;' x 40;  $e->args->[ 0 ] and blessed $e->args->[ 0 ]
      and $errors = "\n\n".( join "\n\n", map { "${_}" } @{ $e->args } );
   my $page   =  {
      content => "${e}${errors}\n\n   Code: ".$e->rv,
      editing => FALSE,
      format  => 'markdown',
      mtime   => time,
      name    => $title,
      title   => $title,
      type    => 'generated' };
   my $stash  =  $self->get_content( $req, $page );

   $stash->{code} = $e->rv >= HTTP_OK ? $e->rv : HTTP_BAD_REQUEST;
   return $stash;
}

sub execute {
   my ($self, $method, @args) = @_;

   $self->can( $method ) and return $self->$method( @args );

   throw 'Class [_1] has no method [_2]', [ blessed $self, $method ];
}

sub get_content : Role(any) {
   my ($self, $req, $page) = @_; my $stash = $self->initialise_stash( $req );

   $stash->{page} = $self->load_page ( $req, $page  );
   $stash->{nav } = $self->navigation( $req, $stash );

   return $stash;
}

sub initialise_stash {
   return { code => HTTP_OK, view => $_[ 0 ]->config->default_view, };
}

sub load_page {
   my ($self, $req, $page) = @_; $page //= {};

   for my $k (qw( authenticated host language mode username )) {
      $page->{ $k } = $req->$k();
   }

   $page->{hint} = $req->loc( 'Hint' );
   return $page;
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
