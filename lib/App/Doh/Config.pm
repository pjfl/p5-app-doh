package App::Doh::Config;

use namespace::autoclean;

use Class::Usul::Constants       qw( NUL TRUE );
use Class::Usul::Crypt::Util     qw( decrypt_from_config encrypt_for_config );
use Class::Usul::File;
use Class::Usul::Functions       qw( app_prefix create_token );
use Data::Validation::Constants  qw( );
use File::DataClass::Types       qw( ArrayRef Bool CodeRef Directory File
                                     HashRef NonEmptySimpleStr
                                     NonNumericSimpleStr
                                     NonZeroPositiveInt Object Path
                                     PositiveInt SimpleStr Str Undef );
use Type::Utils                  qw( enum );
use Web::ComposableRequest::Util qw( extract_lang );
use Moo;

extends q(Class::Usul::Config::Programs);

Data::Validation::Constants->Exception_Class( 'Class::Usul::Exception' );
Web::ComposableRequest::Constants->Exception_Class( 'Class::Usul::Exception' );

my $BLOCK_MODES = enum 'Block_Modes' => [ 1, 2, 3 ];

# Private functions
my $_to_array_of_hash = sub {
   my ($href, $key_key, $val_key) = @_;

   return [ map { my $v = $href->{ $_ }; +{ $key_key => $_, $val_key => $v } }
            sort keys %{ $href } ],
};

# Attribute constructors
my $_build_cdnjs = sub {
   my $self  = shift;
   my %cdnjs = map { $_->[ 0 ] => $self->cdn.$_->[ 1 ] } @{ $self->jslibs };

   return \%cdnjs;
};

my $_build_colours = sub {
   return $_to_array_of_hash->( $_[ 0 ]->_colours, 'key', 'value' );
};

my $_build_links = sub {
   return $_to_array_of_hash->( $_[ 0 ]->_links, 'name', 'url' );
};

my $_build_secret = sub {
   my $self = shift; my $file = $self->ctlfile; my $data = {}; my $token;

   if ($file->exists) {
      $data  = Class::Usul::File->data_load( paths => [ $file ] ) // {};
      $token = decrypt_from_config $self, $data->{ 'secret' };
   }

   unless ($token) {
      $data->{ 'secret' } = encrypt_for_config $self, $token = create_token;
      Class::Usul::File->data_dump( { path => $file->assert, data => $data } );
   }

   return $token;
};

my $_build_user_home = sub {
   my $appldir = $_[ 0 ]->appldir; my $verdir = $appldir->basename;

   return $verdir =~ m{ \A v \d+ \. \d+ p (\d+) \z }msx
        ? $appldir->dirname : $appldir;
};

# Public attributes
has 'analytics'       => is => 'ro',   isa => SimpleStr, default => NUL;

has 'assetdir'        => is => 'lazy', isa => Path, coerce => TRUE,
   builder            => sub { $_[ 0 ]->file_root->catfile( $_[ 0 ]->assets ) };

has 'assets'          => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'assets/',

has 'auth_roles'      => is => 'ro',   isa => ArrayRef[NonEmptySimpleStr],
   default            => sub { [ qw( admin editor user ) ] };

has 'author'          => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'anon';

has 'blank_template'  => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'blank';

has 'brand'           => is => 'ro',   isa => SimpleStr, default => NUL;

has 'cdn'             => is => 'ro',   isa => SimpleStr, default => NUL;

has 'cdnjs'           => is => 'lazy', isa => HashRef,
   builder            => $_build_cdnjs, init_arg => undef;

has 'colours'         => is => 'lazy', isa => ArrayRef[HashRef],
   builder            => $_build_colours, init_arg => undef;

has 'components'      => is => 'lazy', isa => HashRef, builder => sub { {
   'Model::User'      => {
      path            => $_[ 0 ]->file_root->catfile( 'users.json' ), }, } };

has 'compress_css'    => is => 'ro',   isa => Bool, default => TRUE;

has 'css'             => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'css/';

has 'default_route'   => is => 'lazy', isa => NonEmptySimpleStr,
   builder            => sub {
      (my $mp = $_[ 0 ]->mount_point) =~ s{ \A / \z }{}mx;
      return "${mp}/".$_[ 0 ]->static.'/'.$_[ 0 ]->locale.'/index.html' };

has 'default_view'    => is => 'ro',   isa => SimpleStr, default => 'html';

has 'deflate_types'   => is => 'ro',   isa => ArrayRef[NonEmptySimpleStr],
   builder            => sub {
      [ qw( text/css text/html text/javascript application/javascript ) ] };

has 'description'     => is => 'ro',   isa => SimpleStr,
   default            => 'Site Description';

has 'docs_path'       => is => 'lazy', isa => Directory, coerce => TRUE,
   builder            => sub { $_[ 0 ]->root->catdir( 'docs' ) };

has 'drafts'          => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'drafts';

has 'extensions'      => is => 'ro',   isa => HashRef[ArrayRef],
   builder            => sub { {
      markdown        => [ qw( md mkdn )   ],
      pod             => [ qw( pl pm pod ) ], } };

has 'file_root'       => is => 'lazy', isa => Directory, coerce => TRUE,
   builder            => sub { $_[ 0 ]->docs_path };

has 'font'            => is => 'ro',   isa => SimpleStr, default => NUL;

has 'help_url'        => is => 'ro',   isa => SimpleStr, default => 'pod';

has 'images'          => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'img/';

has 'js'              => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'js/';

has 'jslibs'          => is => 'ro',   isa => ArrayRef, builder => sub { [] };

has 'keywords'        => is => 'ro',   isa => SimpleStr, default => NUL;

has 'languages'       => is => 'lazy', isa => ArrayRef[NonEmptySimpleStr],
   builder            => sub { [ map { extract_lang $_ } @{ $_[0]->locales } ]},
   init_arg           => undef;

has 'layout'          => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'standard';

has 'less'            => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'less/';

has 'less_files'      => is => 'ro',   isa => ArrayRef[NonEmptySimpleStr],
   builder            => sub { [ qw( blue editor green navy red ) ] };

has 'links'           => is => 'lazy', isa => ArrayRef[HashRef],
   builder            => $_build_links, init_arg => undef;

has 'mdn_tab_width'   => is => 'ro',   isa => NonZeroPositiveInt, default => 3;

has 'max_asset_size'  => is => 'ro',   isa => PositiveInt, default => 4_194_304;

has 'max_messages'    => is => 'ro',   isa => NonZeroPositiveInt, default => 3;

has 'max_sess_time'   => is => 'ro',   isa => PositiveInt, default => 3_600;

has 'mount_point'     => is => 'ro',   isa => NonEmptySimpleStr,
   default            => '/doh';

has 'no_index'        => is => 'ro',   isa => ArrayRef[NonEmptySimpleStr],
   builder            => sub {
      [ qw( \.git$ \.htpasswd$ \.json$ \.mtime$ \.svn$ assets$ posts$ ) ] };

has 'owner'           => is => 'lazy', isa => NonEmptySimpleStr,
   builder            => sub { $_[ 0 ]->prefix };

has 'port'            => is => 'lazy', isa => NonZeroPositiveInt,
   default            => 8085;

has 'posts'           => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'posts';

has 'projects'        => is => 'ro',   isa => HashRef,   default => sub { {} };

has 'repo_url'        => is => 'ro',   isa => SimpleStr, default => NUL;

has 'request_roles'   => is => 'ro',   isa => ArrayRef[NonEmptySimpleStr],
   builder            => sub { [ 'L10N', 'Session', 'Static' ] };

has 'root_mtime'      => is => 'lazy', isa => Path, coerce => TRUE,
   builder            => sub { $_[ 0 ]->file_root->catfile( '.mtime' ) };

has 'scrubber'        => is => 'ro',   isa => Str,
   default            => '[^ +\-\./0-9@A-Z\\_a-z~]';

has 'secret'          => is => 'lazy', isa => NonEmptySimpleStr,
   builder            => $_build_secret;

has 'serve_as_static' => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'css | favicon.ico | img | js | less';

has 'server'          => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'Starman';

has 'session_attr'    => is => 'lazy', isa => HashRef[ArrayRef],
   builder            => sub { {
      code_blocks     => [ $BLOCK_MODES,      1             ],
      float           => [ Bool,              TRUE          ],
      query           => [ SimpleStr | Undef                ],
      skin            => [ NonEmptySimpleStr, $_[ 0 ]->skin ],
      theme           => [ NonEmptySimpleStr, 'green'       ],
      use_flags       => [ Bool,              TRUE          ], } };

has 'skin'            => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'default';

has 'stash_attr'      => is => 'lazy', isa => HashRef[ArrayRef],
   builder            => sub { {
      config          => [ qw( author description keywords template ) ],
      links           => [ qw( assets css help_url images js less ) ],
      request         => [ qw( authenticated host language mode username ) ],
      session         => [ sort keys %{ $_[ 0 ]->session_attr } ], } };

has 'static'          => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'static';

has 'template'        => is => 'ro',   isa => ArrayRef[NonEmptySimpleStr],
   builder            => sub { [ 'docs', 'docs' ] };

has 'title'           => is => 'ro',   isa => NonEmptySimpleStr,
   default            => 'Documentation';

has 'twitter'         => is => 'ro',   isa => ArrayRef, builder => sub { [] };

has 'user'            => is => 'ro',   isa => SimpleStr, default => NUL;

has 'user_home'       => is => 'lazy', isa => Path, coerce => TRUE,
   builder            => $_build_user_home;

# Private attributes
has '_colours'        => is => 'ro',   isa => HashRef,
   builder            => sub { {} }, init_arg => 'colours';

has '_links'          => is => 'ro',   isa => HashRef,
   builder            => sub { {} }, init_arg => 'links';

1;

__END__

=pod

=encoding utf-8

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

=item C<assetdir>

Defaults to F<var/root/docs/assets>. Path object for the directory
containing user uploaded files

=item C<assets>

A non empty simple string that defaults to F<assets/>. Relative URI path
that locates the assets files uploaded by users

=item C<auth_roles>

The list of roles applicable to authorisation. Defaults to C<admin>,
C<editor>, and C<user>

=item C<author>

A non empty simple string that defaults to C<anon>. The HTML meta attributes
author value

=item C<blank_template>

Name of the template file to use when creating new markdown files

=item C<brand>

A simple string that defaults to null. The name of the image file used
on the splash screen to represent the application

=item C<cdn>

A simple string containing the URI prefix for the content delivery network.
Defaults to null

=item C<cdnjs>

A hash reference of URIs for JavaScript libraries stored on the
content delivery network. Created prepending L</cdn> to each of the
L</jslibs> values

=item C<colours>

A lazily evaluated array reference of hashes created automatically from the
hash reference in the configuration file. Each hash has a single
key / value pair, the colour name and it's hash value. If specified
creates a custom colour scheme for the project

=item C<components>

A hash reference containing component specific configuration options. Keyed
by component classname with the leading application class removed. e.g.

   $self->config->components->{ 'Controller::Root' };

Defines attributes for these components;

=over 3

=item C<Model::User>

Defines these attributes;

=over 3

=item C<load_factor>

Defaults to 14. A non zero positive integer passed to the C<bcrypt> function

=item C<min_pass_len>

Defaults to 8. The minimum acceptable length for a password

=item C<path>

Defaults to F<var/root/docs/users.json>. A file object which contains the
users and their profile used by the application

=back

=back

=item C<compress_css>

Boolean default to true. Should the C<make_css> method compress it's output

=item C<css>

A non empty simple string that defaults to F<css/>. Relative URI path
that locates the static CSS files

=item C<default_route>

A non empty simple string that default to F</doh/static/en/index.html> assuming
that the L</mount_point> is F</doh>. What to redirect to for all paths outside
the mount point

=item C<default_view>

Simple string that default to C<html>. The moniker of the view that will be
used by default to render the response

=item C<deflate_types>

An array reference of non empty simple strings. The list of mime types to
deflate in L<Plack> middleware

=item C<description>

A simple string that defaults to null. The HTML meta attributes description
value

=item C<docs_path>

A lazily evaluated directory that defaults to F<var/root/docs>. The document
root for the microformat content pages

=item C<drafts>

A non empty simple string. Prepended to the pathanme of files created in
draft mode. Draft mode files are ignored by the static site generator

=item C<extensions>

A hash reference. The keys are microformat names and the values are an
array reference of filename extensions that the corresponding view can
render

=item C<file_root>

The project's document root. Lazily evaluated it defaults to C<docs_path>

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

=item C<jslibs>

An array reference of tuples. The first element is the library name, the second
is a partial URI for a JavaScript library stored on the content delivery
network. Defaults to an empty list

=item C<keywords>

A simple string that defaults to null. The HTML meta attributes keyword
list value

=item C<languages>

A array reference of string derived from the list of configuration locales
The value is constructed on demand and has no initial argument

=item C<layout>

A non empty simple string that defaults to F<standard>. The name of the
L<Template::Toolkit> template used to render the HTML response page. The
template will be wrapped by F<wrapper.tt>

=item C<less>

A non empty simple string that defaults to F<less/>. Relative URI path that
locates the static Less files

=item C<less_files>

The list of predefined colour schemes and feature specific less files

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

=item C<max_messages>

Non zero positive integer defaults to 3. The maximum number of messages to
store in the session between requests

=item C<max_sess_time>

Time in seconds before a session expires. Defaults to 15 minutes

=item C<mount_point>

A non empty simple string that defaults to F</doh>. The root of the URI on
which the application is mounted

=item C<no_index>

An array reference that defaults to C<[ .git .svn cgi-bin doh.json ]>. List of
files and directories under the document root to ignore

=item C<owner>

A non empty simple string that defaults to the configuration C<prefix>
attribute. Name of the user and group that should own all files and
directories in the application when installed

=item C<port>

A lazily evaluated non zero positive integer that defaults to 8085. This
is the port number that the documentation server will listen on by default
when started by the control daemon

=item C<posts>

A non empty simple string the defaults to F<posts>.  The directory
name where dated markdown files are created in category
directories. These are the blogs posts or news articles

=item C<projects>

A hash reference that defaults to an empty hash reference. The keys are
port numbers and the values are paths to the document roots of different
projects. Multiple servers can be started on different port numbers each
with their document root and local configuration file in that document root
directory

=item C<request_roles>

Defaults to C<L10N>, C<Session>, and C<Static>. The list of roles to apply to
the default request base class

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

=item C<serve_as_static>

A non empty simple string which defaults to
C<css | favicon.ico | img | js | less>. Selects the resources that are served
by L<Plack::Middleware::Static>

=item C<server>

A non empty simple string that defaults to C<Starman>. The L<Plack> engine
name to load when the documentation server is started in production mode

=item C<session_attr>

A hash reference of array references. These attributes are added to the ones
in L<Web::ComposableRequest::Session> to created the session class. The hash
key is the attribute name and the tuple consists of a type and a optional
default value. The default list of attributes is;

=over 3

=item C<code_blocks>

An integer which defaults to 1. Can be 1 (shown code blocks), 2 (show
code blocks inline), or 3 (hide code blocks)

=item C<float>

A non numeric simple string which defaults to C<float-view>. The default
view mode

=item C<query>

Default search string

=item C<theme>

A non empty simple string that defaults to C<green>. The name of the
default colour scheme

=item C<use_flags>

Boolean which defaults to C<TRUE>. Display the language code, which is
derived from browsers accept language header value, as a national flag. If
false display as text

=back

=item C<skin>

A non empty simple string that defaults to C<default>. The name of the default
skin used to theme the appearance of the application

=item C<stash_attr>

A hash reference of array references. The keys indicate a data source and the
values are lists of attribute names. The values of the named attributes are
copied into the stash. Defines the following keys and values;

=over 3

=item C<config>

The list of configuration attributes whose values are copied to the C<page>
hash reference in the stash

=item C<common_links>

An array reference that defaults to C<[ assets css help_url images less js ]>.
The application pre-calculates URIs for these static directories for use
in the HTML templates

=item C<request>

The list of request attributes whose values are copied to the C<page> hash
reference in the stash

=item C<session>

An array reference that defaults to the keys of the L</session_attr> hash
reference. List of attributes that can be specified as query parameters in
URIs. Their values are persisted between requests stored in the session store

=back

=item C<static>

The default name for the sub-directory of the C<root> directory that will
contain the static HTML pages. Defaults to C<static>

=item C<template>

If the selected L<Template::Toolkit> layout is F<standard> then this
attribute selects which left and right columns templates are rendered

=item C<title>

A non empty simple string that defaults to C<Documentation>. The documentation
project's title as displayed in the title bar of all pages

=item C<twitter>

An array reference that defaults to an empty array reference. List of
Twitter follow buttons

=item C<user>

Simple string that defaults to null. If set the daemon process will change
to running as this user when it forks into the background

=item C<user_home>

The home directory of the user who owns the files and directories in the
the application

=back

=head1 Subroutines/Methods

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Class::Usul::Config>

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
