package App::Doh::Model::Help;

use namespace::sweep;

use Moo;
use Class::Usul::Constants;
use Class::Usul::Functions qw( find_source );
use Class::Usul::Types     qw( ArrayRef );
use File::DataClass::IO;

extends q(App::Doh::Model);
with    q(App::Doh::Role::CommonLinks);
with    q(App::Doh::Role::PageConfiguration);
with    q(App::Doh::Role::Preferences);

# Public attributes
has '_navigation' => is => 'lazy', isa => ArrayRef, builder => sub {
   my $self     = shift;
   my $appclass = $self->config->appclass;
   my $help_url = $self->config->help_url;
  (my $path     = find_source( $appclass )) =~ s{ \.pm }{}mx;
   my $io       = io( $path )->filter( sub { m{ (?: \.pm | \.pod ) \z }mx } );
   my $paths    = [ NUL, grep { not m{ \A (?: Auth | Model | Role | View ) }mx }
                         map  { $_->abs2rel( $path ) } $io->deep->all_files ];
   my $classes  = [ map { s{ (?: :: | \.pm ) \z }{}mx; $_ }
                    map { s{ [/] }{::}gmx; "${appclass}::${_}" } @{ $paths } ];
   my @nav      = ( { level => 0, name => 'Home', type => 'file', url => NUL });

   for my $class (@{ $classes }) {
      push @nav, { level => 0, name => $class, type => 'file',
                   url   => "${help_url}/${class}" };
   }

   return \@nav;
};

# Construction
around 'load_page' => sub {
   my ($orig, $self, $req, @args) = @_;

   my $title = $req->loc( 'Help' );
   my $want  = $req->args->[ 0 ] || $self->config->appclass;
   my $page  = {
      content      => io( find_source( $want ) || $req->args->[ 0 ] ),
      format       => 'pod',
      header       => "${title} - ${want}",
      title        => $title,
      url          => 'https://metacpan.org/module/%s', };

   return $orig->( $self, $req, $page );
};

# Public methods
sub content_from_pod {
   return $_[ 0 ]->get_stash( $_[ 1 ], $_[ 0 ]->load_page( $_[ 1 ] ) );
}

sub navigation {
   return $_[ 0 ]->_navigation;
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
