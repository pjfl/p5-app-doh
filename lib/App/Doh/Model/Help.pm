package App::Doh::Model::Help;

use namespace::autoclean;

use Class::Usul::Constants qw( NUL TRUE );
use Class::Usul::Functions qw( find_source );
use Class::Usul::Types     qw( ArrayRef );
use File::DataClass::IO;
use Moo;

extends q(App::Doh::Model);
with    q(App::Doh::Role::PageConfiguration);

# Public attributes
has '+moniker'    => default => 'help';

has 'excluding'   => is => 'ro', isa => ArrayRef, builder => sub {
   [ qw( Attributes Auth Markdown Model Role Session Util View ) ] };

# Private attributes
has '_navigation' => is => 'lazy', isa => ArrayRef, builder => sub {
   my $self     = shift;
   my $appclass = $self->config->appclass;
   my $help_url = $self->config->help_url;
  (my $path     = find_source( $appclass )) =~ s{ \.pm }{}mx;
   my $io       = io( $path )->filter( sub { m{ (?: \.pm | \.pod ) \z }mx } );
   my $exclude  = join ' | ', @{ $self->excluding };
   my $paths    = [ NUL, grep { not m{ \A (?: $exclude ) }mx }
                         map  { $_->abs2rel( $path ) } $io->deep->all_files ];
   my $classes  = [ map { s{ (?: :: | \.pm ) \z }{}mx; $_ }
                    map { s{ [/] }{::}gmx; "${appclass}::${_}" } @{ $paths } ];
   my @nav      = ();

   for my $class (@{ $classes }) {
      push @nav, { depth => 0, title => ucfirst $class, type => 'file',
                   url   => "${help_url}/${class}" };
   }

   return \@nav;
};

# Construction
around 'load_page' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $parent  =  $req->loc( 'Help' );
   my $opts    =  { optional => TRUE, scrubber => '[^0-9A-Z_a-z:]' };
   my $args0   =  $req->uri_params->( 0, $opts );
   my $name    =  $args0 // $self->config->appclass;
   my $page    =  {
      content  => io( find_source( $name ) || $args0 ),
      format   => 'pod',
      name     => $name,
      parent   => $parent,
      title    => ucfirst $name,
      url      => 'https://metacpan.org/module/%s', };

   return $orig->( $self, $req, $page );
};

# Public methods
sub navigation {
   return $_[ 0 ]->_navigation;
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
