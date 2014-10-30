package App::Doh::CLI;

use namespace::autoclean;

use Moo;
use App::Doh;
use App::Doh::Functions    qw( env_var iterator load_components );
use Archive::Tar::Constant qw( COMPRESS_GZIP );
use Class::Usul::Constants qw( FALSE NUL OK TRUE );
use Class::Usul::Functions qw( app_prefix io );
use Class::Usul::Options;
use Class::Usul::Types     qw( HashRef LoadableClass NonEmptySimpleStr Object
                               PositiveInt );

extends q(Class::Usul::Programs);

our $VERSION = $App::Doh::VERSION;

# Override default in base class
has '+config_class' => default => 'App::Doh::Config';

# Public attributes
has 'less'  => is => 'lazy', isa => Object, builder => sub {
   my $self = shift;
   my $conf = $self->config;
   my $incd = $conf->root->catdir( 'less' );

   return $self->less_class->new( compress      => $conf->compress_css,
                                  include_paths => [ "${incd}" ],
                                  tmp_path      => $conf->tempdir, );
};

has 'less_class'      => is => 'lazy', isa => LoadableClass,
   default            => 'CSS::LESS';

option 'max_gen_time' => is => 'ro',   isa => PositiveInt,
   documentation      => 'Maximum generation run time in seconds',
   default            => 1_800, format => 'i', short => 'm';

has 'models'          => is => 'lazy', isa => HashRef[Object], builder => sub {
   load_components    'Model', { builder  => $_[ 0 ], } };

option 'skin'         => is => 'ro',   isa => NonEmptySimpleStr,
   documentation      => 'Name of the skin to operate on',
   default            => sub { $_[ 0 ]->config->skin }, format => 's',
   short              => 's';

# Construction
around 'BUILDARGS' => sub {
   my ($orig, $self, @args) = @_; my $attr = $orig->( $self, @args );

   my $conf = $attr->{config}; my $prefix = app_prefix $conf->{appclass};

   $conf->{l10n_attributes}->{domains} = [ $prefix ];
   $conf->{logfile} = "__LOGSDIR(${prefix}.log)__";
   return $attr;
};

# Public methods
sub make_css : method {
   my $self = shift;
   my $conf = $self->config;
   my $cssd = $conf->root->catdir( $conf->css );

   if (my $file = $self->next_argv) { $self->_write_theme( $cssd, $file ) }
   else { $self->_write_theme( $cssd, $_ ) for (@{ $conf->less_files }) }

   return OK;
}

sub make_skin : method {
   my $self = shift; my $conf = $self->config; my $skin = $self->skin;

   require Archive::Tar; my $arc = Archive::Tar->new;

   for my $path ($conf->root->catdir( $conf->less, $skin )->all_files) {
      $arc->add_files( $path->abs2rel( $conf->appldir ) );
   }

   for my $path ($conf->root->catdir( 'templates', $skin )->all_files) {
      $arc->add_files( $path->abs2rel( $conf->appldir ) );
   }

   my $path = $conf->root->catfile( $conf->js, "${skin}.js" );

   $arc->add_files( $path->abs2rel( $conf->appldir ) );
   $self->info( "Generating tarball for the ${skin} skin" );
   $arc->write( "${skin}-skin.tgz", COMPRESS_GZIP );
   return OK;
}

sub make_static : method {
   # TODO: Add caching to stop uneeded regeneration. Use mod times
   my $self = shift; my $conf = $self->config; my $models = $self->models;

   my $opts = { async => TRUE, k => 'make_static', t => $self->max_gen_time };

   unless ($self->lock->set( $opts )) {
      $self->info( 'Static page generation already in progress' ); return OK;
   }

   my $dest = io( $self->next_argv // $conf->static );

   env_var( 'MAKE_STATIC', TRUE );
   $self->info( 'Generating static pages' );
   $dest->is_absolute or $dest = io( $dest->rel2abs( $conf->root ) );
   $self->_copy_assets( $dest );

   for my $locale ($models->{docs}->locales) {
      my $tree = $models->{docs}->localised_tree( $locale );

      $self->_make_localised_static( $dest, $tree, $locale, FALSE );
      $tree = $models->{posts}->localised_tree( $locale );
      $self->_make_localised_static( $dest, $tree, $locale, TRUE );
   }

   $self->lock->reset( k => 'make_static' );
   return OK;
}

# Private methods
sub _copy_assets {
   my ($self, $dest) = @_; my $conf = $self->config; my $root = $conf->root;

   $dest->exists or $dest->mkpath; $dest->rmtree( { keep_root => TRUE } );

   my ($unwanted_images, $unwanted_js, $unwanted_less);

   if ($conf->colours->[ 0 ]) {
      my $files = join '|', @{ $conf->less_files };

      $unwanted_images = qr{ favicon \- (?: $files ) }mx;
      $unwanted_less   = qr{ theme   \- (?: $files ) }mx;

      __deep_copy( $root->catdir( $conf->less ), $dest, $unwanted_less );
   }
   else {
      $unwanted_images = qr{ favicon\.png  }mx;
      $unwanted_js     = qr{ less\.min\.js }mx;

      __deep_copy( $root->catdir( $conf->css ), $dest );
   }

   __deep_copy( $conf->file_root->catdir( $conf->assets ), $dest );
   __deep_copy( $root->catdir( $conf->images ), $dest, $unwanted_images );
   __deep_copy( $root->catdir( $conf->js     ), $dest, $unwanted_js );
   return;
}

sub _make_localised_static {
   my ($self, $dest, $tree, $locale, $make_dirs) = @_;

   my $conf = $self->config; my $iter = iterator( $tree );

   while (my $node = $iter->()) {
      not $make_dirs and $node->{type} eq 'folder' and next;

      my $url  = '/'.$node->{url}."?locale=${locale}\;mode=static";
      my $cmd  = [ $conf->binsdir->catfile( 'doh-server' ), $url ];
      my @path = split m{ / }mx, "${locale}/".$node->{url}.'.html';
      my $path = io( [ $dest, @path ] )->assert_filepath;

      $self->info( "Writing ${locale}/".$node->{url} );
      $self->run_cmd( $cmd, { out => $path } );
   }

   return;
}

sub _write_theme {
   my ($self, $cssd, $file) = @_;

   my $skin = $self->skin;
   my $conf = $self->config;
   my $path = $conf->root->catfile( $conf->less, $skin, "${file}.less" );
   my $css  = $self->less->compile( $path->all );

   $self->info( "Writing ${skin}-${file} theme" );
   $cssd->catfile( "${skin}-${file}.css" )->println( $css );
   return;
}

# Private functions
sub __deep_copy {
   my ($src, $dest, $excluding) = @_;

   $src->exists or return; $excluding //= qr{ NUL() }mx;

   my $filter = sub { $_->is_file && $_ !~ $excluding };
   my $iter   = $src->deep->filter( $filter )->iterator;

   while (my $from = $iter->()) {
      my $to = $dest->catfile( $from->abs2rel( $src->parent ) );

      $from->copy( $to->assert_filepath );
   }

   return;
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

   bin/doh-cli make_css [theme]

Creates CSS files under F<var/root/css> one for each colour theme. If a colour
theme name is supplied only the C<LESS> for that theme is compiled

=head2 C<make_skin> - Make a tarball of the files for a skin

   bin/doh-cli -s name_of_skin make_skin

Creates a tarball in the current directory containing the C<LESS>
files, templates, and JavaScript code for the named skin. Defaults to the
F<default> skin

=head2 C<make_static> - Make a static HTML copy of the documentation

   bin/doh-cli make_static

Creates static HTML pages under F<var/root/static>

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

Copyright (c) 2014 Peter Flanigan. All rights reserved

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
