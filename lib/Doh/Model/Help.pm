# @(#)Ident: Help.pm 2013-07-20 23:58 pjf ;

package Doh::Model::Help;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 11 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Functions  qw( find_source );
use Class::Usul::Types      qw( ArrayRef );
use File::DataClass::IO;
use Moo;

extends q(Doh);

has '_nav' => is => 'lazy', isa => ArrayRef;

sub get_stash {
   my ($self, $req) = @_; my $conf = $self->config;

   return { config   => $conf,
            nav      => $self->_nav,
            page     => __get_page( $conf, $req ),
            template => 'documentation',
            theme    => $req->{params}->{ 'theme' } || $conf->theme, };
}

sub _build__nav {
   my $self     = shift;
   my $appclass = $self->config->appclass;
  (my $path     = find_source( $appclass )) =~ s{ \.pm }{}mx;
   my $io       = io( $path )->filter( sub { m{ (?: \.pm | \.pod ) \z }mx } );
   my $paths    = [ NUL, grep { not m{ \A (?: Model | View ) }mx }
                         map  { $_->abs2rel( $path ) } $io->deep->all_files ];
   my $classes  = [ map { s{ (?: :: | \.pm ) \z }{}mx; $_ }
                    map { s{ [/] }{::}gmx; "${appclass}::${_}" } @{ $paths } ];
   my @nav      = ( { level => 0, name => 'Home', type => 'file', url => '/' });

   for my $class (@{ $classes }) {
      push @nav, { level => 0, name => $class, type => 'file',
                   url   => "/help/${class}" };
   }

   return \@nav;
}

sub __get_page {
   my ($conf, $req) = @_; my $want = $req->{args}->[ 0 ] || $conf->appclass;

   return { content  => {
               src   => find_source( $want ) || $req->{args}->[ 0 ],
               title => "${want} Help",
               url   => 'https://metacpan.org/module/%s', },
            format   => 'pod', };
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
