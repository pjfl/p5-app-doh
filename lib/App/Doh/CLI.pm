package App::Doh::CLI;

use namespace::autoclean;

use App::Doh; our $VERSION = $App::Doh::VERSION;

use App::Doh::Functions    qw( env_var iterator );
use Archive::Tar::Constant qw( COMPRESS_GZIP );
use Class::Usul::Constants qw( FALSE NUL OK TRUE );
use Class::Usul::Functions qw( app_prefix class2appdir ensure_class_loaded io );
use Class::Usul::Types     qw( Bool HashRef LoadableClass
                               NonEmptySimpleStr Object PositiveInt );
use English                qw( -no_match_vars );
use File::DataClass::Types qw( Path );
use User::grent;
use User::pwent;
use Web::Components::Util  qw( load_components );
use Moo;
use Class::Usul::Options;  # Requires around, has, and with

extends 'Class::Usul::Programs';

# Attribute constructors
my $_build_less = sub {
   my $self = shift;
   my $conf = $self->config;
   my $incd = $conf->root->catdir( 'less' );

   return $self->less_class->new( compress      => $conf->compress_css,
                                  include_paths => [ "${incd}" ],
                                  tmp_path      => $conf->tempdir, );
};

# Public attributes
option 'force'        => is => 'ro',   isa => Bool,
   documentation      => 'Force the operation to take place',
   default            => FALSE, short => 'f';

option 'max_gen_time' => is => 'ro',   isa => PositiveInt, format => 'i',
   documentation      => 'Maximum generation run time in seconds',
   default            => 1_800, short => 'm';

option 'skin'         => is => 'lazy', isa => NonEmptySimpleStr, format => 's',
   documentation      => 'Name of the skin to operate on',
   builder            => sub { $_[ 0 ]->config->skin }, short => 's';

has '+config_class'   => default => 'App::Doh::Config';

has 'less'            => is => 'lazy', isa => Object, builder => $_build_less;

has 'less_class'      => is => 'lazy', isa => LoadableClass,
   default            => 'CSS::LESS';

has 'models'          => is => 'lazy', isa => HashRef[Object],
   builder            => sub { load_components 'Model', application => $_[0] };

# Construction
around 'BUILDARGS' => sub {
   my ($orig, $self, @args) = @_; my $attr = $orig->( $self, @args );

   my $conf = $attr->{config}; my $prefix = app_prefix $conf->{appclass};

   $conf->{l10n_attributes}->{domains} = [ $prefix ];
   $conf->{logfile} = "__LOGSDIR(${prefix}.log)__";
   return $attr;
};

# Private functions
my $_deep_copy = sub {
   my ($src, $dest, $excluding) = @_;

   $src->exists or return; $excluding //= qr{ NUL() }mx;

   my $filter = sub { $_->is_file && $_ !~ $excluding };
   my $iter   = $src->deep->filter( $filter )->iterator;

   while (my $from = $iter->()) {
      my $to = $dest->catfile( $from->abs2rel( $src->parent ) );

      $from->copy( $to->assert_filepath );
   }

   return;
};

my $_init_file_list = sub {
   return io[ NUL, 'etc', 'init.d', $_[ 0 ] ],
          io[ NUL, 'etc', 'rc0.d', 'K01'.$_[ 0 ] ];
};

# Private methods
my $_copy_assets = sub {
   my ($self, $dest) = @_; my $conf = $self->config; my $root = $conf->root;

   my ($unwanted_images, $unwanted_js, $unwanted_less);

   if ($conf->colours->[ 0 ]) {
      my $files = join '|', @{ $conf->less_files };

      $unwanted_images = qr{ favicon \- (?: $files ) }mx;
      $unwanted_less   = qr{ theme   \- (?: $files ) }mx;

      $_deep_copy->( $root->catdir( $conf->less ), $dest, $unwanted_less );
   }
   else {
      $unwanted_images = qr{ favicon\.png  }mx;
      $unwanted_js     = qr{ less\.min\.js }mx;

      $_deep_copy->( $root->catdir( $conf->css ), $dest );
   }

   $_deep_copy->( $conf->file_root->catdir( $conf->assets ), $dest );
   $_deep_copy->( $root->catdir( $conf->images ), $dest, $unwanted_images );
   $_deep_copy->( $root->catdir( $conf->js     ), $dest, $unwanted_js );
   return;
};

my $_make_localised_static = sub {
   my ($self, $dest, $tree, $locale, $make_dirs) = @_;

   my $conf = $self->config; my $iter = iterator $tree;

   while (my $node = $iter->()) {
      not $make_dirs and $node->{type} eq 'folder' and next;

      my @path = split m{ / }mx, "${locale}/".$node->{url}.'.html';
      my $path = io( [ $dest, @path ] )->assert_filepath;

      $path->exists and $path->stat->{mtime} > $node->{date} and next;

      my $url  = '/'.$node->{url}."?locale=${locale}\;mode=static";
      my $cmd  = [ $conf->binsdir->catfile( 'doh-server' ), $url ];

      $self->info( 'Writing [_1]', { args => [ "${locale}/".$node->{url} ] } );
      $self->run_cmd( $cmd, { out => $path } );
   }

   return;
};

my $_write_theme = sub {
   my ($self, $cssd, $file) = @_;

   my $skin = $self->skin;
   my $conf = $self->config;
   my $path = $conf->root->catfile( $conf->less, $skin, "${file}.less" );

   $path->exists or return;

   my $css  = $self->less->compile( $path->all );

   $self->info( 'Writing theme file [_1]', { args => [ "${skin}-${file}" ] } );
   $cssd->catfile( "${skin}-${file}.css" )->println( $css );
   return;
};

# Public methods
sub make_css : method {
   my $self = shift;
   my $conf = $self->config;
   my $cssd = $conf->root->catdir( $conf->css );

   if (my $file = $self->next_argv) { $self->$_write_theme( $cssd, $file ) }
   else { $self->$_write_theme( $cssd, $_ ) for (@{ $conf->less_files }) }

   return OK;
}

sub make_skin : method {
   my $self = shift; my $conf = $self->config; my $skin = $self->skin;

   ensure_class_loaded 'Archive::Tar'; my $arc = Archive::Tar->new;

   for my $path ($conf->root->catdir( $conf->less, $skin )->all_files) {
      $arc->add_files( $path->abs2rel( $conf->appldir ) );
   }

   for my $path ($conf->root->catdir( 'templates', $skin )->all_files) {
      $arc->add_files( $path->abs2rel( $conf->appldir ) );
   }

   my $path = $conf->root->catfile( $conf->js, "${skin}.js" );

   $arc->add_files( $path->abs2rel( $conf->appldir ) );
   $self->info( 'Generating tarball for [_1] skin', { args => [ $skin ] } );
   $arc->write( "${skin}-skin.tgz", COMPRESS_GZIP );
   return OK;
}

sub make_site_tarball : method {
   my $self = shift; my $conf = $self->config; $self->make_static;

   ensure_class_loaded 'Archive::Tar'; my $arc = Archive::Tar->new;

   my $static = $conf->root->catdir( $conf->static ); chdir "${static}";
   my $filter = sub { $_ !~ m{ [/\\] \. }mx };

   for my $path ($static->filter( $filter )->deep->all_files) {
      $arc->add_files( $path->abs2rel( $static ) );
   }

   $self->info( 'Generating site tarball' );
   $arc->write( $conf->appldir->catfile( 'site.tgz' ), COMPRESS_GZIP );
   return OK;
}

sub make_static : method {
   my $self = shift; my $conf = $self->config; my $models = $self->models;

   my $opts = { async => TRUE, k => 'make_static', t => $self->max_gen_time };

   unless ($self->lock->set( $opts )) {
      $self->info( 'Static page generation already in progress' ); return OK;
   }

   my $dest = io( $self->next_argv // $conf->static );

   env_var $conf->appclass, 'MAKE_STATIC', TRUE;
   $self->info( 'Generating static pages' );
   $dest->is_absolute or $dest = io( $dest->rel2abs( $conf->root ) );
   $dest->exists or $dest->mkpath;
   $self->force and $dest->rmtree( { keep_root => TRUE } );
   $self->$_copy_assets( $dest );

   for my $locale ($models->{docs}->locales) {
      my $tree = $models->{docs}->localised_tree( $locale );

      $self->$_make_localised_static( $dest, $tree, $locale, FALSE );
      $tree = $models->{posts}->localised_tree( $locale );
      $self->$_make_localised_static( $dest, $tree, $locale, TRUE );
   }

   $self->lock->reset( k => 'make_static' );
   return OK;
}

sub post_install : method {
   my $self     = shift;
   my $conf     = $self->config;
   my $appldir  = $conf->appldir;
   my $verdir   = $appldir->basename;
   my $localdir = $appldir->catdir( 'local' );
   my $appname  = class2appdir $conf->appclass;
   my $inc      = $localdir->catdir( 'lib', 'perl5'   );
   my $profile  = $localdir->catdir( 'etc', 'profile' );
   my $cmd      = [ $EXECUTABLE_NAME, '-I', "${inc}",
                    "-Mlocal::lib=${localdir}" ];

   $localdir->exists
      and $profile->assert_filepath
      and $self->run_cmd( $cmd, { err => 'stderr', out => $profile } );

   if ($verdir =~ m{ \A v \d+ \. \d+ p (\d+) \z }msx) {
      my $owner = my $group = $conf->owner;

      getgr( $group ) or $self->run_cmd( [ 'groupadd', '--system', $group ] );

      unless (getpwnam( $owner )) {
         $self->run_cmd( [ 'useradd', '--home', $conf->user_home, '--gid',
                           $group, '--no-user-group', '--system', $owner  ] );
         $self->run_cmd( [ 'chown', "${owner}:${group}", $conf->user_home ] );
      }

      $self->run_cmd( [ 'chown', "${owner}:${group}", $appldir ] );
      $self->run_cmd( [ 'chown', '-R', "${owner}:${group}", $appldir ] );
   }

   my ($init, $kill) = $_init_file_list->( $appname );

   $cmd = [ $conf->binsdir->catfile( 'doh-daemon' ), 'get-init-file' ];

   $init->exists or $self->run_cmd( $cmd, { out => $init } );
   $init->is_executable or $init->chmod( 0750 );
   $kill->exists or $self->run_cmd( [ 'update-rc.d', $appname, 'defaults' ] );
   return OK;
}

sub uninstall : method {
   my $self    = shift;
   my $conf    = $self->config;
   my $appname = class2appdir $conf->appclass;

   my ($init, $kill) = $_init_file_list->( $appname );

   $init->exists and $self->run_cmd( [ 'invoke-rc.d', $appname, 'stop' ],
                                     { expected_rv => 1 } );
   $kill->exists and $self->run_cmd( [ 'update-rc.d', $appname, 'remove' ] );
   $init->unlink;
   return OK;
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::Doh::CLI - Command line interface class for the application

=head1 Synopsis

   use App::Doh::CLI;

   exit App::Doh::Cli->new( appclass => 'App::Doh', noask => 1 )->run;

=head1 Description

Command line interface class for the application

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<model>

A reference to the L<App::Doh::Model::Documentation> object

=back

=head1 Subroutines/Methods

=head2 C<make_css> - Compile CSS files from LESS files

   bin/doh-cli make-css [theme]

Creates CSS files under F<var/root/css> one for each colour theme. If a colour
theme name is supplied only the C<LESS> for that theme is compiled

=head2 C<make_site_tarball> - Make a tarball of the static site

   bin/doh-cli make-site-tarball

Creates a tarball of the sites static files

=head2 C<make_skin> - Make a tarball of the files for a skin

   bin/doh-cli -s name_of_skin make-skin

Creates a tarball in the current directory containing the C<LESS>
files, templates, and JavaScript code for the named skin. Defaults to the
F<default> skin

=head2 C<make_static> - Make a static HTML copy of the documentation

   bin/doh-cli make-static

Creates static HTML pages under F<var/root/static>

=head2 C<post_install> - Perform post installation tasks

   bin/doh-cli post-install

Performs a sequence of tasks after installation of the applications files
is complete

=head2 C<uninstall> - Remove the application from the system

   bin/doh-cli uninstall

Uninstalls the application

=head1 Diagnostics

Output is logged to the file F<var/logs/app_doh.log>

=head1 Dependencies

=over 3

=item L<Class::Usul>

=item L<File::DataClass>

=item L<Moo>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-Doh.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2015 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE

=cut

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
