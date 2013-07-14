# @(#)$Ident: Build.PL 2013-07-13 19:45 pjf ;

use strict;
use warnings;
use inc::Bob; # Module::Build subclass
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 2 $ =~ /\d+/gmx );

Bob->new( {
   module    => 'Daux',
   home_page => 'http://www.roxsoft.co.uk',
   requires  => {
      'perl'            => 5.01,
      'Class::Usul'     => q(0.19.0),
      'File::DataClass' => q(0.21.0),
      'Text::Markdown'  => 1.000031,
   },
   recommends           => {
      'App::cpanminus'  => 1.6005, },
   configure_requires   => {
      'version'         => 0.88,
      'Module::Build'   => 0.4004, },
   build_requires       => {
      'version'         => 0.88,
      'Module::Build'   => 0.4004, },
} )->create_build_script; # Goal!

# Local Variables:
# mode: perl
# eval: (load-project-state "daux")
# tab-title: Daux
# tab-width: 3
# End:
