package App::Doh::Model::Help;

use namespace::sweep;

use Moo;
use Class::Usul::Constants;
use Class::Usul::Functions qw( find_source );
use Class::Usul::Types     qw( ArrayRef );
use File::DataClass::IO;

extends q(App::Doh);
with    q(App::Doh::Role::CommonLinks);
with    q(App::Doh::Role::PageConfiguration);
with    q(App::Doh::Role::Preferences);

# Public attributes
has 'navigation' => is => 'lazy', isa => ArrayRef, builder => sub {
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

# Public methods
sub get_stash {
   my ($self, $req) = @_;

   return { nav      => $self->navigation,
            page     => $self->load_page( $req ),
            template => 'documentation', };
}

sub load_page {
   my ($self, $req) = @_;

   my $title = $req->loc( 'Help' );
   my $want  = $req->args->[ 0 ] || $self->config->appclass;

   return { content => io( find_source( $want ) || $req->args->[ 0 ] ),
            format  => 'pod',
            header  => "${title} - ${want}",
            title   => $title,
            url     => 'https://metacpan.org/module/%s', };
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
