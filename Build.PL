# @(#)$Ident: Build.PL 2013-07-21 11:18 pjf ;

use strict;
use warnings;
use inc::Bob; # Module::Build subclass
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 12 $ =~ /\d+/gmx );

Bob->new( {
   module    => 'Doh',
   home_page => 'http://www.roxsoft.co.uk',
   requires  => {
      'perl'             => 5.01,
      'namespace::sweep' => 0.006,
      'Class::Usul'      => q(0.22.0),
      'Daemon::Control'  => q(0.000_009),
      'File::DataClass'  => q(0.21.0),
      'HTML::Accessors'  => q(0.8.0),
      'Moo'              => 1.002,
      'MooX::Options'    => 3.83,
      'Plack'            => 1.0018,
      'Plack::Middleware::Deflater'  => 0.08,
      'Plack::Middleware::LogErrors' => 0.001,
      'Pod::Xhtml'       => 1.61,
      'Template'         => 2.22,
      'Text::Markdown'   => 1.000031,
      'Web::Simple'      => 0.020, },
   recommends            => {
      'App::cpanminus'   => 1.6005, },
   configure_requires    => {
      'version'          => 0.88,
      'Module::Build'    => 0.4004, },
   build_requires        => {
      'version'          => 0.88,
      'Module::Build'    => 0.4004, },
} )->create_build_script; # Goal!

# Local Variables:
# mode: perl
# eval: (load-project-state "doh")
# tab-title: Doh
# tab-width: 3
# End:
