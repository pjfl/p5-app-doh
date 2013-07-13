# @(#)$Ident: Build.PL 2013-05-11 10:26 pjf ;

use strict;
use warnings;
use inc::Bob; # Module::Build subclass
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 1 $ =~ /\d+/gmx );

Bob->new( {
   module    => q(Daux),
   home_page => q(http://www.roxsoft.co.uk),
   requires  => {
      'perl'           => 5.01,
      'Class::Usul'    => q(0.19.0),
   },
   recommends          => {
      'App::cpanminus' => 1.6005, },
   configure_requires  => {
      'version'        => 0.88,
      'Module::Build'  => 0.4004, },
   build_requires      => {
      'version'        => 0.88,
      'Module::Build'  => 0.4004, },
} )->create_build_script; # Goal!

# Local Variables:
# mode: perl
# eval: (load-project-state "daux")
# tab-title: Daux
# tab-width: 3
# End:
