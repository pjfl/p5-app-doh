package App::Doh::Config;

use namespace::sweep;

use Moo;
use Class::Usul::Constants;
use File::DataClass::Types qw( ArrayRef Bool Directory HashRef Int
                               NonEmptySimpleStr NonNumericSimpleStr
                               NonZeroPositiveInt SimpleStr );
use Sys::Hostname          qw( hostname );

extends q(Class::Usul::Config::Programs);

has 'author'           => is => 'ro',   isa => NonEmptySimpleStr,
   default             => 'Dave';

has 'brand'            => is => 'ro',   isa => SimpleStr, default => NUL;

has 'code_blocks'      => is => 'ro',   isa => Int, default => 1;

has 'colours'          => is => 'lazy', isa => ArrayRef, init_arg => undef;

has 'common_links'     => is => 'ro',   isa => ArrayRef,
   builder             => sub { [ qw( css help_url images js less ) ] };

has 'css'              => is => 'ro',   isa => NonEmptySimpleStr,
   default             => 'css/';

has 'default_content'  => is => 'ro',   isa => NonEmptySimpleStr,
   default             => 'Page intentionally created blank';

has 'description'      => is => 'ro',   isa => SimpleStr, default => NUL;

has 'docs_path'        => is => 'lazy', isa => Directory,
   builder             => sub { $_[ 0 ]->root->catdir( 'docs' ) },
   coerce              => Directory->coercion;

has 'extensions'       => is => 'ro',   isa => HashRef,
   builder             => sub { { markdown => [ qw( md mkdn )   ],
                                  pod      => [ qw( pl pm pod ) ], } };

has 'file_root'        => is => 'lazy', isa => Directory,
   builder             => sub { $_[ 0 ]->docs_path },
   coerce              => Directory->coercion;

has 'float'            => is => 'ro',   isa => Bool, default => TRUE;

has 'font'             => is => 'ro',   isa => SimpleStr,
   default             => sub {
      'http://fonts.googleapis.com/css?family=Roboto+Slab:400,700,300,100' };

has 'google_analytics' => is => 'ro',   isa => SimpleStr, default => NUL;

has 'help_url'         => is => 'ro',   isa => SimpleStr, default => 'help';

has 'images'           => is => 'ro',   isa => NonEmptySimpleStr,
   default             => 'img/';

has 'js'               => is => 'ro',   isa => NonEmptySimpleStr,
   default             => 'js/';

has 'keywords'         => is => 'ro',   isa => SimpleStr, default => NUL;

has 'languages'        => is => 'lazy', isa => ArrayRef[NonEmptySimpleStr],
   builder             => sub {
      return [ map { (split m{ _ }mx, $_)[ 0 ] } @{ $_[ 0 ]->locales } ];
   };

has 'less'             => is => 'ro',   isa => NonEmptySimpleStr,
   default             => 'less/';

has 'links'            => is => 'lazy', isa => ArrayRef, init_arg => undef;

has 'mount_point'      => is => 'ro',   isa => NonEmptySimpleStr,
   default             => '/';

has 'no_index'         => is => 'ro',   isa => ArrayRef,
   builder             => sub {
      [ qw( .git .htpasswd .mtime .svn app-doh.json ) ] };

has 'port'             => is => 'lazy', isa => NonZeroPositiveInt,
   default             => 8085;

has 'preferences'      => is => 'ro',   isa => ArrayRef,
   builder             => sub { [ qw( code_blocks float skin theme ) ] };

has 'projects'         => is => 'ro',   isa => HashRef,   default => sub { {} };

has 'repo_url'         => is => 'ro',   isa => SimpleStr, default => NUL;

has 'secret'           => is => 'ro',   isa => NonEmptySimpleStr,
   default             => hostname;

has 'server'           => is => 'ro',   isa => NonEmptySimpleStr,
   default             => 'Twiggy';

has 'skin'             => is => 'ro',   isa => NonEmptySimpleStr,
   default             => 'default';

has 'template'         => is => 'ro',   isa => NonEmptySimpleStr,
   default             => 'index';

has 'theme'            => is => 'ro',   isa => NonEmptySimpleStr,
   default             => 'green';

has 'title'            => is => 'ro',   isa => NonEmptySimpleStr,
   default             => 'Documentation';

has 'twitter'          => is => 'ro',   isa => ArrayRef, builder => sub { [] };


has '_colours'         => is => 'ro',   isa => HashRef,
   builder             => sub { {} }, init_arg => 'colours';

has '_links'           => is => 'ro',   isa => HashRef,
   builder             => sub { {} }, init_arg => 'links';

# Private methods
sub _build_colours {
   return __to_array_of_hash( $_[ 0 ]->_colours, qw( key value ) );
}

sub _build_links {
   return __to_array_of_hash( $_[ 0 ]->_links, qw( name url ) );
}

# Private functions
sub __to_array_of_hash {
   my ($href, $key_key, $val_key) = @_;

   return [ map { my $v = $href->{ $_ }; +{ $key_key => $_, $val_key => $v } }
            sort keys %{ $href } ],
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::Doh::Config - Defines the configuration file options and their defaults

=head1 Synopsis

   use Class::Usul;

   my $usul = Class::Usul->new( config_class => 'App::Doh::Config' );

   my $author = $usul->config->author;

=head1 Description

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<author>

A non empty simple string that defaults to C<Dave>. The HTML meta attributes
author value

=item C<brand>

A simple string that defaults to null. The name of the image file used
on the splash screen to represent the application

=item C<colours>

A lazily evaluated array reference of hashes created automatically from the
hash reference in the configuration file. Each hash has a single
key / value pair, the colour name and it's hash value. If specified
creates a custom colour scheme for the project

=item C<common_links>

An array reference that defaults to C<[ css help_url images less js ]>.
The application pre-calculates URIs for these static directories for use
in the HTML templates

=item C<css>

A non empty simple string that defaults to F<css/>. Relative URI path
that locates the static CSS files

=item C<default_content>

The string of text that is the content of any new markdown files

=item C<description>

A simple string that defaults to null. The HTML meta attributes description
value

=item C<docs_path>

A lazily evaluated directory that defaults to F<var/root/docs>. The document
root for the microformat content pages

=item C<extensions>

A hash reference. The keys are microformat names and the values are an
array reference of filename extensions that the corresponding view can
render

=item C<file_root>

The project's document root. Lazily evaluated it defaults to C<docs_path>

=item C<float>

A non numeric simple string which defaults to C<float-view>. The default
view mode

=item C<font>

A simple string that defaults to
C<http://fonts.googleapis.com/css?family=Roboto+Slab:400,700,300,100>. The
default font used to display text

=item C<google_analytics>

A simple string that defaults to null. Unique Google Analytics registration
code

=item C<help_url>

A simple string that defaults to C<help>. The partial URI path which locates
this POD when rendered as HTML and served by this application

=item C<images>

A non empty simple string that defaults to F<img/>. Relative URI path that
locates the static image files

=item C<js>

A non empty simple string that defaults to F<js/>. Relative URI path that
locates the static JavaScript files

=item C<keywords>

A simple string that defaults to null. The HTML meta attributes keyword
list value

=item C<less>

A non empty simple string that defaults to F<less/>. Relative URI path that
locates the static Less files

=item C<links>

A lazily evaluated array reference of hashes created automatically from the
hash reference in the configuration file. Each hash has a single
key / value pair, the link name and it's URI. The links are displayed in
the navigation panel and the footer in the default templates

=item C<mount_point>

A non empty simple string that defaults to F</>. The root of the URI on
which the application is mounted

=item C<no_index>

An array reference that defaults to C<[ .git .svn cgi-bin doh.json ]>. List of
files and directories under the document root to ignore

=item C<port>

A lazily evaluated non zero positive integer that defaults to 8085. This
is the port number that the documentation server will listen on by default
when started by the control daemon

=item C<preferences>

An array reference that defaults to C<[ float skin theme ]>. List of
attributes that can be specified as query parameters in URIs.  Their
values are persisted between requests stored in cookie

=item C<projects>

A hash reference that defaults to an empty hash reference. The keys are
port numbers and the values are paths to the document roots of different
projects. Multiple servers can be started on different port numbers each
with their document root and local configuration file in that document root
directory

=item C<repo_url>

A simple string that defaults to null. The URI of the source code repository
for this project

=item C<server>

A non empty simple string that defaults to C<Twiggy>. The L<Plack> engine
name to load when the documentation server is started

=item C<skin>

A non empty simple string that defaults to C<default>. The name of the default
skin used to theme the appearance of the application

=item C<template>

A non empty simple string that defaults to C<index>. The name of the
L<Template::Toolkit> template used to render the HTML response page

=item C<theme>

A non empty simple string that defaults to C<green>. The name of the
default colour scheme

=item C<title>

A non empty simple string that defaults to C<Documentation>. The documentation
project's title as displayed in the title bar of all pages

=item C<twitter>

An array reference that defaults to an empty array reference. List of
Twitter follow buttons

=back

=head1 Subroutines/Methods

None

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

There are no known bugs in this module.
Please report problems to the address below.
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
