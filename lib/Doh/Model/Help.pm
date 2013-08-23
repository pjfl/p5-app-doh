# @(#)Ident: Help.pm 2013-08-22 23:46 pjf ;

package Doh::Model::Help;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 19 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Functions  qw( find_source );
use Class::Usul::Types      qw( ArrayRef );
use File::DataClass::IO;
use Moo;

extends q(Doh);
with    q(Doh::TraitFor::CommonLinks);
with    q(Doh::TraitFor::Preferences);

has 'navigation' => is => 'lazy', isa => ArrayRef;

sub get_stash {
   my ($self, $req) = @_;

   return { nav      => $self->navigation,
            page     => $self->load_page( $req ),
            template => 'documentation', };
}

sub load_page {
   my ($self, $req) = @_;

   my $want = $req->args->[ 0 ] || $self->config->appclass;

   return { content => io( find_source( $want ) || $req->args->[ 0 ] ),
            format  => 'pod',
            title   => "${want} Help",
            url     => 'https://metacpan.org/module/%s', };
}

# Private methods
sub _build_navigation {
   my $self     = shift;
   my $appclass = $self->config->appclass;
   my $url      = $self->config->generator_url;
  (my $path     = find_source( $appclass )) =~ s{ \.pm }{}mx;
   my $io       = io( $path )->filter( sub { m{ (?: \.pm | \.pod ) \z }mx } );
   my $paths    = [ NUL, grep { not m{ \A (?: Model | TraitFor | View ) }mx }
                         map  { $_->abs2rel( $path ) } $io->deep->all_files ];
   my $classes  = [ map { s{ (?: :: | \.pm ) \z }{}mx; $_ }
                    map { s{ [/] }{::}gmx; "${appclass}::${_}" } @{ $paths } ];
   my @nav      = ( { level => 0, name => 'Home', type => 'file', url => '/' });

   for my $class (@{ $classes }) {
      push @nav, { level => 0, name => $class, type => 'file',
                   url   => "${url}/${class}" };
   }

   return \@nav;
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
