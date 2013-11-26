# @(#)Ident: Help.pm 2013-11-23 14:31 pjf ;

package App::Doh::Model::Help;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 22 $ =~ /\d+/gmx );

use Moo;
use Class::Usul::Constants;
use Class::Usul::Functions  qw( find_source );
use Class::Usul::Types      qw( ArrayRef );
use File::DataClass::IO;

extends q(App::Doh);
with    q(App::Doh::TraitFor::CommonLinks);
with    q(App::Doh::TraitFor::Preferences);

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
   my $help_url = $self->config->help_url;
  (my $path     = find_source( $appclass )) =~ s{ \.pm }{}mx;
   my $io       = io( $path )->filter( sub { m{ (?: \.pm | \.pod ) \z }mx } );
   my $paths    = [ NUL, grep { not m{ \A (?: Model | TraitFor | View ) }mx }
                         map  { $_->abs2rel( $path ) } $io->deep->all_files ];
   my $classes  = [ map { s{ (?: :: | \.pm ) \z }{}mx; $_ }
                    map { s{ [/] }{::}gmx; "${appclass}::${_}" } @{ $paths } ];
   my @nav      = ( { level => 0, name => 'Home', type => 'file', url => NUL });

   for my $class (@{ $classes }) {
      push @nav, { level => 0, name => $class, type => 'file',
                   url   => "${help_url}/${class}" };
   }

   return \@nav;
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
