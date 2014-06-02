package App::Doh::CLI;

use namespace::sweep;

use Moo;
use App::Doh;
use App::Doh::Functions    qw( iterator );
use App::Doh::Model::Documentation;
use App::Doh::Model::Posts;
use Class::Usul::Constants qw( EXCEPTION_CLASS NUL OK TRUE );
use Class::Usul::Functions qw( throw );
use Class::Usul::Types     qw( HashRef Object );
use File::DataClass::IO    qw( io );
use Unexpected::Types      qw( LoadableClass );

extends q(Class::Usul::Programs);

our $VERSION = $App::Doh::VERSION;

# Override default in base class
has '+config_class' => default => 'App::Doh::Config';

has 'less'  => is => 'lazy', isa => Object, builder => sub {
   my $self = shift;
   my $conf = $self->config;
   my $incd = $conf->root->catdir( 'less' );

   return $self->less_class->new( compress      => $conf->compress_css,
                                  include_paths => [ "${incd}" ],
                                  tmp_path      => $conf->tempdir, );
};

has 'less_class' => is => 'lazy', isa => LoadableClass,
   default       => 'CSS::LESS';

has 'models' => is => 'lazy', isa => HashRef[Object], builder => sub {
   { 'docs'  => App::Doh::Model::Documentation->new( builder => $_[ 0 ] ),
     'posts' => App::Doh::Model::Posts->new( builder => $_[ 0 ] ), } };

# Public methods
sub make_css : method {
   my $self  = shift;
   my $conf  = $self->config;
   my $cssd  = $conf->root->catdir( 'css' );

   if (my $theme = $self->next_argv) { $self->_write_theme( $cssd, $theme ) }
   else { $self->_write_theme( $cssd, $_ ) for (@{ $conf->themes }) }

   return OK;
}

sub make_static : method {
   my $self = shift; my $dest = io( $self->next_argv // $self->config->static );

   $ENV{DOH_MAKE_STATIC} = TRUE;
   $self->log->info( 'Generating static pages' );
   $dest->is_absolute or $dest = io( $dest->rel2abs( $self->config->root ) );
   $self->_copy_assets( $dest );

   for my $locale ($self->models->{docs}->locales) {
      my $tree = $self->models->{docs}->localised_tree( $locale );

      $self->_make_localised_static( $tree, $dest, $locale );
      $tree = $self->models->{posts}->localised_tree( $locale );
      $self->_make_localised_static( $tree, $dest, $locale );
   }

   return OK;
}

# Private methods
sub _copy_assets {
   my ($self, $dest) = @_; my $conf = $self->config; my $root = $conf->root;

   $dest->exists or $dest->mkpath; $dest->rmtree( { keep_root => TRUE } );

   my ($unwanted_images, $unwanted_js, $unwanted_less);

   if ($conf->colours->[ 0 ]) {
      my $themes = join '|', @{ $conf->themes };

      $unwanted_images = qr{ favicon \- (?: $themes ) }mx;
      $unwanted_less   = qr{ theme   \- (?: $themes ) }mx;

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
   my ($self, $tree, $dest, $locale) = @_;

   my $conf = $self->config; my $iter = iterator( $tree );

   while (my $node = $iter->()) {
      $node->{type} eq 'folder' and next;

      my $url  = '/'.$node->{url}."?locale=${locale}\;mode=static";
      my $cmd  = [ $conf->binsdir->catfile( 'doh-server' ), $url ];
      my @path = split m{ / }mx, "${locale}/".$node->{url}.'.html';
      my $path = io( [ $dest, @path ] )->assert_filepath;

      $self->info( 'Writing '.$locale.'/'.$node->{url} );
      $path->print( $self->run_cmd( $cmd )->stdout );
   }

   return;
}

sub _write_theme {
   my ($self, $cssd, $theme) = @_;

   my $conf = $self->config;
   my $path = $conf->root->catfile( 'less', "theme-${theme}.less" );
   my $css  = $self->less->compile( $path->all );

   $self->info( "Writing ${theme} theme" );
   $cssd->catfile( "theme-${theme}.css" )->println( $css );
   return;
}

# Private functions
sub __deep_copy {
   my ($src, $dest, $excluding) = @_; $excluding //= qr{ NUL() }mx;

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

=head2 C<make_static> - Make a static HTML copy of the documentation

   bin/doh-cli make_static

Creates static HTML pages under F<var/root/static>

=head1 Diagnostics

None

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
