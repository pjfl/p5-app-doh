package App::Doh::Config;

use namespace::autoclean;

use Class::Usul::Constants qw( NUL TRUE );
use Class::Usul::Functions qw( app_prefix );
use File::DataClass::Types qw( ArrayRef Bool Directory HashRef Int
                               NonEmptySimpleStr NonNumericSimpleStr
                               NonZeroPositiveInt Path SimpleStr Str );
use Sys::Hostname          qw( hostname );
use Type::Utils            qw( enum );
use Moo;

extends q(Class::Usul::Config::Programs);

my $BLOCK_MODES = enum 'Block_Modes' => [ 1, 2, 3 ];

has 'analytics'       => is => 'ro',   isa => SimpleStr, default => NUL;

has 'assets'          => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'assets/',

has 'assetdir'        => is => 'lazy', isa => Path,
   builder            => sub { $_[ 0 ]->file_root->catfile( $_[ 0 ]->assets ) },
   coerce             => Path->coercion;

has 'author'          => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'anon';

has 'blank_template'  => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'blank';

has 'brand'           => is => 'ro',   isa => SimpleStr, default => NUL;

has 'code_blocks'     => is => 'ro',   isa => $BLOCK_MODES, default => 1;

has 'colours'         => is => 'lazy', isa => ArrayRef, init_arg => undef;

has 'common_links'    => is => 'ro',   isa => ArrayRef,
   builder            => sub { [ qw( assets css help_url images js less ) ] };

has 'compress_css'    => is => 'ro',   isa => Bool, default => TRUE;

has 'css'             => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'css/';

has 'default_skin'    => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'default';

has 'description'     => is => 'ro',   isa => SimpleStr,
   default            => 'Site Description';

has 'docs_path'       => is => 'lazy', isa => Directory,
   builder            => sub { $_[ 0 ]->root->catdir( 'docs' ) },
   coerce             => Directory->coercion;

has 'extensions'      => is => 'ro',   isa => HashRef,
   builder            => sub { { markdown => [ qw( md mkdn )   ],
                                 pod      => [ qw( pl pm pod ) ], } };

has 'file_root'       => is => 'lazy', isa => Directory,
   builder            => sub { $_[ 0 ]->docs_path },
   coerce             => Directory->coercion;

has 'float'           => is => 'ro',   isa => Bool, default => TRUE;

has 'font'            => is => 'ro',   isa => SimpleStr, default => NUL;

has 'help_url'        => is => 'ro',   isa => SimpleStr, default => 'pod';

has 'images'          => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'img/';

has 'js'              => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'js/';

has 'keywords'        => is => 'ro',   isa => SimpleStr, default => NUL;

has 'languages'       => is => 'lazy', isa => ArrayRef[NonEmptySimpleStr],
   builder            => sub {
      [ map { (split m{ _ }mx, $_)[ 0 ] } @{ $_[ 0 ]->locales } ] },
   init_arg           => undef;

has 'less'            => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'less/';

has 'links'           => is => 'lazy', isa => ArrayRef, init_arg => undef;

has 'mdn_tab_width'   => is => 'ro',   isa => NonZeroPositiveInt, default => 3;

has 'max_asset_size'  => is => 'ro',   isa => Int, default => 4_194_304;

has 'mount_point'     => is => 'ro',   isa => NonEmptySimpleStr,
   default            => '/';

has 'no_index'        => is => 'ro',   isa => ArrayRef,
   builder            => sub {
      [ qw( \.git$ \.htpasswd$ \.json$ \.mtime$ \.svn$ assets$ posts$ ) ] };

has 'port'            => is => 'lazy', isa => NonZeroPositiveInt,
   default            => 8085;

has 'posts'           => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'posts';

has 'preferences'     => is => 'ro',   isa => ArrayRef,
   builder            => sub {
      [ qw( code_blocks float query skin theme use_flags ) ] };

has 'projects'        => is => 'ro',   isa => HashRef,   default => sub { {} };

has 'query'           => is => 'ro',   isa => SimpleStr, default => NUL;

has 'repo_url'        => is => 'ro',   isa => SimpleStr, default => NUL;

has 'root_mtime'      => is => 'lazy', isa => Path, coerce => Path->coercion,
   builder            => sub { $_[ 0 ]->file_root->catfile( '.mtime' ) };

has 'scrubber'        => is => 'ro',   isa => Str,
   default            => '[^ +\-\./0-9A-Z\\_a-z~]';

has 'secret'          => is => 'ro',   isa => NonEmptySimpleStr,
   default            => hostname;

has 'server'          => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'Starman';

has 'skin'            => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'default';

has 'static'          => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'static';

has 'template'        => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'documentation';

has 'theme'           => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'green';

has 'themes'          => is => 'ro',   isa => ArrayRef,
   builder            => sub { [ qw( blue green navy red ) ] };

has 'title'           => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'Documentation';

has 'twitter'         => is => 'ro',   isa => ArrayRef, builder => sub { [] };

has 'use_flags'       => is => 'ro',   isa => Bool, default => TRUE;

has 'user_roles'      => is => 'ro',   isa => HashRef[ArrayRef],
   default            => sub { { admin => [ 'editor', 'user' ] } };

has '_colours'        => is => 'ro',   isa => HashRef,
   builder            => sub { {} }, init_arg => 'colours';

has '_links'          => is => 'ro',   isa => HashRef,
   builder            => sub { {} }, init_arg => 'links';

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

Each of the attributes defined here, plus the ones inherited from
L<Class::Usul::Config::Programs>, can have their default value overridden
by the value in the configuration file

=head1 Configuration and Environment

The configuration file is, by default, in JSON format

It is found by calling the L<find_apphome|Class::Usul::Functions/find_apphome>
function

Defines the following attributes;

=over 3

=item C<analytics>

A simple string that defaults to null. Unique Google Analytics registration
code

=item C<assets>

A non empty simple string that defaults to F<assets/>. Relative URI path
that locates the assets files uploaded by users

=item C<assetdir>

Defaults to F<var/root/assets>. Path object for the directory
containing user uploaded files

=item C<author>

A non empty simple string that defaults to C<Dave>. The HTML meta attributes
author value

=item C<blank_template>

Name of the template file to use when creating new markdown files

=item C<brand>

A simple string that defaults to null. The name of the image file used
on the splash screen to represent the application

=item C<code_blocks>

An integer which defaults to 1. Can be 1 (shown code blocks), 2 (show
code blocks inline), or 3 (hide code blocks)

=item C<colours>

A lazily evaluated array reference of hashes created automatically from the
hash reference in the configuration file. Each hash has a single
key / value pair, the colour name and it's hash value. If specified
creates a custom colour scheme for the project

=item C<common_links>

An array reference that defaults to C<[ assets css help_url images less js ]>.
The application pre-calculates URIs for these static directories for use
in the HTML templates

=item C<compress_css>

Boolean default to true. Should the C<make_css> method compress it's output

=item C<css>

A non empty simple string that defaults to F<css/>. Relative URI path
that locates the static CSS files

=item C<default_skin>

Simple string that default to F<default>. The name of the default template
directory

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

A simple string that defaults to null. The default font used to
display text headings

=item C<help_url>

A simple string that defaults to C<pod>. The partial URI path which locates
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

=item C<languages>

A array reference of string derived from the list of configuration locales
The value is constructed on demand and has no initial argument

=item C<less>

A non empty simple string that defaults to F<less/>. Relative URI path that
locates the static Less files

=item C<links>

A lazily evaluated array reference of hashes created automatically from the
hash reference in the configuration file. Each hash has a single
key / value pair, the link name and it's URI. The links are displayed in
the navigation panel and the footer in the default templates

=item C<mdn_tab_width>

Non zero positive integer defaults to 3. The number of spaces required to
indent a code block in the markdown class

=item C<max_asset_size>

Integer defaults to 4Mb. Maximum size in bytes of the file upload

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

=item C<posts>

A non empty simple string the defaults to F<posts>.  The directory
name where dated markdown files are created in category
directories. These are the blogs posts or news articles

=item C<preferences>

An array reference that defaults to
C<[ code_blocks float skin theme use_flags ]>. List of attributes that can be
specified as query parameters in URIs.  Their values are persisted between
requests stored in cookie

=item C<projects>

A hash reference that defaults to an empty hash reference. The keys are
port numbers and the values are paths to the document roots of different
projects. Multiple servers can be started on different port numbers each
with their document root and local configuration file in that document root
directory

=item C<query>

Default search string

=item C<repo_url>

A simple string that defaults to null. The URI of the source code repository
for this project

=item C<root_mtime>

Path object for the document tree modification time file. The indexing program
touches this file setting it to modification time of the most recently changed
file in the document tree

=item C<scrubber>

A string used as a character class in a regular expression. These character
are scrubber from user input so they cannot appear in any user supplied
pathnames or query terms. Defaults to C<[;\$\`&\r\n]>

=item C<secret>

Used to encrypt the session cookie

=item C<server>

A non empty simple string that defaults to C<Starman>. The L<Plack> engine
name to load when the documentation server is started in production mode

=item C<skin>

A non empty simple string that defaults to C<default>. The name of the default
skin used to theme the appearance of the application

=item C<static>

The default name for the sub-directory of the C<root> directory that will
contain the static HTML pages. Defaults to C<static>

=item C<template>

A non empty simple string that defaults to C<index>. The name of the
L<Template::Toolkit> template used to render the HTML response page

=item C<theme>

A non empty simple string that defaults to C<green>. The name of the
default colour scheme

=item C<themes>

The list of predefined colour schemes

=item C<title>

A non empty simple string that defaults to C<Documentation>. The documentation
project's title as displayed in the title bar of all pages

=item C<twitter>

An array reference that defaults to an empty array reference. List of
Twitter follow buttons

=item C<use_flags>

Boolean which defaults to C<TRUE>. Display the language code, which is
derived from browsers accept language header value, as a national flag. If
false display as text

=item C<user_roles>

A hash reference keyed by username. The values are array references of roles
that the user is a member of. Membership of a role if used to grante acces
to pages within the application

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
