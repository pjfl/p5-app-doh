# Build.PL is generated - do not edit
use strict;
use warnings;

use Module::Build 0.4004;
use File::Spec::Functions qw( catdir );

sub testing { $ENV{AUTOMATED_TESTING} || $ENV{PERL_CPAN_REPORTER_CONFIG}
                                      || $ENV{PERL5_CPANPLUS_IS_VERSION} }

sub whimper { print {*STDOUT} $_[ 0 ]."\n"; exit 0 }

my $perl_ver = 5.010001;
my $distname = 'App-Doh'; (my $name = $distname) =~ s{ - }{::}gmx;
my $prereqs  = {
  'build_requires' => {
    'Module::Build' => '0.4004',
    'Test::Requires' => '0.06',
    'Test::Warnings' => '0.014',
    'version' => '0.88'
  },
  'configure_requires' => {
    'Module::Build' => '0.4004',
    'Pod::Perldoc' => '3.23',
    'version' => '0.88'
  },
  'recommends' => {
    'CSS::LESS' => 'v0.0.3'
  },
  'requires' => {
    'App::Ack' => '2.12',
    'Class::Usul' => 'v0.58.0',
    'Crypt::Eksblowfish' => '0.009',
    'Daemon::Control' => '0.001006',
    'Data::Validation' => 'v0.18.0',
    'Exporter::Tiny' => '0.042',
    'File::DataClass' => 'v0.61.0',
    'HTML::Accessors' => 'v0.12.0',
    'HTTP::Body' => '1.19',
    'HTTP::Message' => '6.06',
    'JSON::MaybeXS' => '1.002006',
    'Module::Pluggable' => '5.1',
    'Moo' => '2.000001',
    'Plack' => '1.0032',
    'Plack::Middleware::Debug' => '0.16',
    'Plack::Middleware::Deflater' => '0.08',
    'Plack::Middleware::FixMissingBodyInRedirect' => '0.12',
    'Plack::Middleware::LogErrors' => '0.001',
    'Plack::Middleware::Session' => '0.21',
    'Pod::Xhtml' => '1.61',
    'Starman' => '0.3000',
    'Template' => '2.26',
    'Text::MultiMarkdown' => '1.000034',
    'Try::Tiny' => '0.22',
    'Type::Tiny' => '1.000004',
    'URI' => '1.65',
    'Unexpected' => 'v0.38.0',
    'Web::Simple' => '0.030',
    'YAML::Tiny' => '1.64',
    'local::lib' => '2.000014',
    'namespace::autoclean' => '0.22',
    'namespace::clean' => '0.25',
    'perl' => '5.010001',
    'strictures' => '1.005004',
    'warnings::illegalproto' => '0.001002'
  },
};

if ($] < $perl_ver) { # Not interested in reports below min perl ver
   testing or whimper "Minimum required Perl version is ${perl_ver}";
   $prereqs->{build_requires} = { %{ $prereqs->{configure_requires} } };
   $prereqs->{build_requires}->{ 'Test::Requires' } = 0.06;
   delete $prereqs->{requires};
}

my $bob = Module::Build->subclass( code => do { local $/; <DATA> } )->new(
   'add_to_cleanup' => [ 'debian', 'META.yml' ],
   'module_name'    => $name,
   'notes'          => { min_perl_version => $perl_ver, testing => testing },
   %{ $prereqs },

);

$bob->install_path( 'bin'    => catdir( $bob->install_base, 'bin'   ) );
$bob->install_path( 'lib'    => catdir( $bob->install_base, 'lib'   ) );
$bob->install_path( 'var'    => catdir( $bob->install_base, 'var'   ) );
$bob->install_path( 'local'  => catdir( $bob->install_base, 'local' ) );
$bob->install_path( 'script' => catdir( $bob->install_base, 'bin'   ) );
$bob->install_path( 'bindoc' => catdir( $bob->install_base, 'man', 'man1' ) );
$bob->install_path( 'libdoc' => catdir( $bob->install_base, 'man', 'man3' ) );
$bob->add_build_element( 'config' );
$bob->add_build_element( 'local'  );
$bob->add_build_element( 'var'    );
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

      $self->destdir and $path = catdir( $self->destdir, $path );
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

sub process_local_files {
   my $self = shift; return $self->_process_files( 'local' );
}

sub process_var_files {
   my $self = shift; my $pattern; umask oct '0027';

   for (qw( .git logs run tmp )) {
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
