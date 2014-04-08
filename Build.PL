use strict;
use warnings;

use Module::Build 0.4004;
use File::Spec::Functions qw( catdir );

sub whimper { print {*STDOUT} $_[ 0 ]."\n"; exit 0 }

my $perl_ver = 5.010001;
my $distname = 'App-Doh'; (my $name = $distname) =~ s{ - }{::}gmx;
my $prereqs  = {
  'build_requires' => {
    'Module::Build' => '0.4004',
    'Test::Warnings' => '0.014',
    'version' => '0.88'
  },
  'configure_requires' => {
    'Module::Build' => '0.4004',
    'version' => '0.88'
  },
  'requires' => {
    'Class::Usul' => 'v0.39.0',
    'Daemon::Control' => '0.000009',
    'File::DataClass' => 'v0.34.0',
    'HTML::Accessors' => 'v0.11.0',
    'HTTP::Body' => '1.11',
    'HTTP::Message' => '6.06',
    'Module::Pluggable' => '4.8',
    'Moo' => '1.003',
    'Plack' => '1.0018',
    'Plack::Middleware::Auth::Htpasswd' => '0.02',
    'Plack::Middleware::Deflater' => '0.08',
    'Plack::Middleware::LogErrors' => '0.001',
    'Plack::Middleware::Session' => '0.21',
    'Pod::Xhtml' => '1.61',
    'Template' => '2.22',
    'Text::Markdown' => '1.000031',
    'Try::Tiny' => '0.18',
    'Twiggy' => '0.1021',
    'URI' => '1.60',
    'Unexpected' => 'v0.22.0',
    'Web::Simple' => '0.020',
    'namespace::sweep' => '0.006',
    'perl' => '5.010001'
  },
};

if ($] < $perl_ver) {
   $ENV{AUTOMATED_TESTING}
      or $ENV{PERL_CPAN_REPORTER_CONFIG}
      or $ENV{PERL5_CPANPLUS_IS_VERSION}
      or whimper "Minimum required Perl version is ${perl_ver}";
   $prereqs->{build_requires} = { %{ $prereqs->{configure_requires} } };
   $prereqs->{build_requires}->{ 'Test::Requires' } = 0.06;
   delete $prereqs->{requires};
}

my $bob = Module::Build->subclass( code => do { local $/; <DATA> } )->new(
  'module_name'  => $name,
  'notes'        => { min_perl_version => $perl_ver },
  %{ $prereqs },

);

$bob->install_path( 'lib' => catdir( $bob->install_base, 'lib' ) );
$bob->install_path( 'var' => catdir( $bob->install_base, 'var' ) );
$bob->add_build_element( 'config' );
$bob->add_build_element( 'var' );
$bob->create_build_script;
exit 0;

__DATA__

use File::Basename        qw( dirname );
use File::Copy            qw( copy );
use File::Find            qw( find );
use File::Path            qw( make_path );
use File::Spec::Functions qw( catdir catfile );

sub ACTION_install {
   my $self = shift; umask oct '0007'; $self->SUPER::ACTION_install();

   for my $dir (qw( logs run tmp )) {
      my $path = catdir( $self->install_path( 'var' ), $dir );

      -d $path or make_path( $path, { mode => oct '0770' } );
   }

   return;
}

sub process_config_files {
   my $self     = shift; umask oct '0027';
   my $distname = $self->dist_name;
   my $home     = catdir( 'lib', split m{ - }mx, $distname);

   return $self->_process_files( catfile( $home, (lc $distname).'.json' ) );
}

sub process_var_files {
   my $self = shift; my $pattern; umask oct '0027';

   for (qw( .git logs tmp )) {
      $pattern .= ($pattern ? '|' : q()).(catdir( q(), $_ ));
   }

   $self->_skip_pattern( qr{ (?: $pattern ) }mx );
   return $self->_process_files( 'var' );
}

sub _process_files {
   # Find and copy files and directories from source tree to destination tree
   my ($self, $src, $dest) = @_; $src or return; $dest ||= 'blib';

   if    (-f $src) { $self->_copy_file( $src, $dest ) }
   elsif (-d $src) {
      my $prefix = $self->base_dir;

      find( { no_chdir => TRUE, wanted => sub {
         (my $path = $File::Find::name) =~ s{ \A $prefix }{}mx;
         return $self->_copy_file( $path, $dest );
      }, }, $src );
   }

   return;
}

sub _copy_file {
   my ($self, $src, $dest) = @_; my $pattern = $self->_skip_pattern;

   ($src and -f $src and (not $pattern or $src !~ $pattern)) or return;
   # Rebase the directory path
   my $dir = catdir( $dest, dirname( $src ) );
   # Ensure target directory exists
   -d $dir or make_path( $dir, { mode => oct '0750' } );
   copy( $src, $dir );
   return;
}

sub _skip_pattern { # Accessor/mutator for the regex of paths not to process
   return defined $_[ 1 ] ? $_[ 0 ]->{_skip_pattern} = $_[ 1 ]
                          : $_[ 0 ]->{_skip_pattern};
}
