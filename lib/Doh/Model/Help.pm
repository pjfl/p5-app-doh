# @(#)Ident: Help.pm 2013-07-20 20:31 pjf ;

package Doh::Model::Help;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 10 $ =~ /\d+/gmx );

use Class::Usul::Functions  qw( find_source );
use Moo;

extends q(Doh);

sub get_stash {
   my ($self, $req) = @_; my $conf = $self->config;

   my $src = find_source( $req->{args}->[ 0 ] || 'Doh' ) || $req->{args}->[ 0 ];

   return {
      config   => $conf,
      nav      => [ { level => 0,      name => 'Home',
                      type  => 'file', url  => '/' }, ],
      page     => { content => { src   => $src,
                                 title => $conf->{appclass}.' Help',
                                 url   => 'https://metacpan.org/module/%s', },
                    format  => 'pod', },
      template => 'documentation',
      theme    => $req->{params}->{ 'theme' } || $conf->theme,
   };
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
