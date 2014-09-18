package App::Doh::Request;

use namespace::autoclean;

use Moo;
use App::Doh::Functions    qw( extract_lang );
use App::Doh::Session;
use Class::Usul::Constants qw( EXCEPTION_CLASS NUL SPC TRUE );
use Class::Usul::Functions qw( first_char is_arrayref is_hashref
                               is_member throw trim );
use Class::Usul::Types     qw( ArrayRef BaseType HashRef NonEmptySimpleStr
                               Object PositiveInt SimpleStr Str );
use Encode                 qw( decode );
use HTTP::Body;
use HTTP::Status           qw( HTTP_EXPECTATION_FAILED
                               HTTP_INTERNAL_SERVER_ERROR
                               HTTP_REQUEST_ENTITY_TOO_LARGE );
use Scalar::Util           qw( blessed weaken );
use Try::Tiny;
use Unexpected::Functions  qw( Unspecified );
use URI::http;
use URI::https;

# Public attributes
has 'args'           => is => 'ro',   isa => ArrayRef, default => sub { [] };

has 'base'           => is => 'lazy', isa => Object;

has 'body'           => is => 'lazy', isa => Object;

has 'content_length' => is => 'lazy', isa => PositiveInt,
   builder           => sub { $_[ 0 ]->_env->{CONTENT_LENGTH} // 0 };

has 'content_type'   => is => 'lazy', isa => SimpleStr,
   builder           => sub { $_[ 0 ]->_env->{CONTENT_TYPE} // NUL };

has 'domain'         => is => 'lazy', isa => NonEmptySimpleStr,
   builder           => sub { (split m{ : }mx, $_[ 0 ]->host)[ 0 ] };

has 'encoding'       => is => 'ro',   isa => NonEmptySimpleStr,
   default           => 'UTF-8';

has 'host'           => is => 'lazy', isa => NonEmptySimpleStr, builder => sub {
   my $env           =  $_[ 0 ]->_env;
      $env->{ 'HTTP_HOST' } // $env->{ 'SERVER_NAME' } // 'localhost' };

has 'language'       => is => 'lazy', isa => NonEmptySimpleStr,
   builder           => sub { extract_lang $_[ 0 ]->locale };

has 'locale'         => is => 'lazy', isa => NonEmptySimpleStr;

has 'locales'        => is => 'lazy', isa => ArrayRef;

has 'method'         => is => 'lazy', isa => SimpleStr,
   builder           => sub { lc $_[ 0 ]->_env->{ 'REQUEST_METHOD' } // NUL };

has 'path'           => is => 'lazy', isa => SimpleStr, builder => sub {
   my $v             =  $_[ 0 ]->_env->{ 'PATH_INFO' } // '/';
      $v             =~ s{ \A / }{}mx; $v =~ s{ \? .* \z }{}mx; $v };

has 'query'          => is => 'lazy', isa => SimpleStr, builder => sub {
   my $v             =  $_[ 0 ]->_env->{ 'QUERY_STRING' }; $v ? "?${v}" : NUL };

has 'scheme'         => is => 'lazy', isa => NonEmptySimpleStr,
   builder           => sub { $_[ 0 ]->_env->{ 'psgi.url_scheme' } // 'http' };

has 'script'         => is => 'lazy', isa => SimpleStr, builder => sub {
   my $v             =  $_[ 0 ]->_env->{ 'SCRIPT_NAME' } // '/';
      $v             =~ s{ / \z }{}gmx; $v };

has 'session'        => is => 'lazy', isa => Object, builder => sub {
   App::Doh::Session->new( builder => $_[ 0 ]->_usul, env => $_[ 0 ]->_env ) },
   handles           => [ qw( authenticated username ) ];

has 'tunnel_method'  => is => 'lazy', isa => NonEmptySimpleStr;

has 'uri'            => is => 'lazy', isa => Object;

# Private attributes
has '_content'       => is => 'lazy', isa => Str, init_arg => undef;

has '_env'           => is => 'ro',   isa => HashRef, default => sub { {} };

has '_params'        => is => 'ro',   isa => HashRef, default => sub { {} };

has '_usul'          => is => 'ro',   isa => BaseType,
   handles           => [ qw( config l10n log ) ], required => TRUE;

# Construction
around 'BUILDARGS' => sub {
   my ($orig, $self, @args) = @_; my $attr = {};

   $attr->{_usul  } = shift @args;
   $attr->{_env   } = ($args[ 0 ] and is_hashref $args[ -1 ]) ? pop @args : {};
   $attr->{_params} = ($args[ 0 ] and is_hashref $args[ -1 ]) ? pop @args : {};
   $attr->{args   } = (defined $args[ 0 ] && blessed $args[ 0 ])
                    ? [ $args[ 0 ] ]
                    : [ split m{ / }mx, trim $args[ 0 ] || NUL ];
   return $attr;
};

sub BUILD {
   my $self = shift;

   $self->_decode_array( $self->args ); $self->_decode_hash( $self->_params );

   $self->mode ne 'static' and $self->log->debug
      ( join SPC, (uc $self->method), $self->uri,
        ($self->authenticated ? $self->username : NUL) );
   return;
}

sub _build_base {
   my $self = shift; my $uri;

   if ($self->mode eq 'static') {
      my @path = split m{ / }mx, $self->path; $uri = '../' x scalar @path;
   }
   else { $uri = $self->scheme.'://'.$self->host.$self->script.'/' }

   return bless \$uri, 'URI::'.$self->scheme;
}

sub _build_body {
   my $self = shift; my $env = $self->_env; my $content = $self->_content;

   my $body = HTTP::Body->new( $self->content_type, length $content );

   length $content and $body->add( $content );

   return $body;
}

sub _build__content {
   my $self = shift; my $env = $self->_env; my $content;

   my $cl = $self->content_length  or return NUL;
   my $fh = $env->{ 'psgi.input' } or return NUL;

   try   { $fh->seek( 0, 0 ); $fh->read( $content, $cl, 0 ); $fh->seek( 0, 0 ) }
   catch { $self->log->error( $_ ); $content = undef };

   return $content ? decode( $self->encoding, $content ) : NUL;
}

sub _build_locale {
   my $self   = shift;
   my $locale = $self->query_params( 'locale', { optional => TRUE } );

   $locale and is_member $locale, $self->config->locales and return $locale;

   for my $locale (@{ $self->locales }) {
      is_member $locale, $self->config->locales and return $locale;
   }

   return $self->config->locale;
}

sub _build_locales {
   my $self = shift; my $lang = $self->_env->{ 'HTTP_ACCEPT_LANGUAGE' } || NUL;

   return [ map    { s{ _ \z }{}mx; $_ }
            map    { join '_', $_->[ 0 ], uc $_->[ 1 ] }
            map    { [ split m{ - }mx, $_ ] }
            map    { ( split m{ ; }mx, $_ )[ 0 ] }
            split m{ , }mx, lc $lang ];
}

sub _build_tunnel_method  {
   return  $_[ 0 ]->body_params->(  '_method', { optional => TRUE } )
        || $_[ 0 ]->query_params->( '_method', { optional => TRUE } )
        || 'not_found';
}

sub _build_uri {
   my $self = shift;my $uri;

   if ($self->mode ne 'static') { $uri = $self->base.$self->path }
   else { $uri = $self->base.$self->locale.'/'.$self->path.'.html' }

   return bless \$uri, 'URI::'.$self->scheme;
}

# Public methods
sub body_params {
   my $self = shift; weaken( $self );

   my $params = $self->body->param; weaken( $params );

   return sub { $self->_get_scrubbed_param( $params, @_ ) };
}

sub loc {
   my $self = shift; return $self->l10n->localizer( $self->locale, @_ );
}

sub loc_default {
   my $self = shift; return $self->l10n->localizer( $self->config->locale, @_ );
}

sub mode {
   return $_[ 0 ]->query_params->( 'mode', { optional => TRUE } ) // 'online';
}

sub query_params {
   my $self = shift; weaken( $self );

   my $params = $self->_params; weaken( $params );

   return sub { $self->_get_scrubbed_param( $params, @_ ) };
}

sub uri_for {
   my ($self, $path, $args, @query_params) = @_;

   $args and defined $args->[ 0 ] and $path = join '/', $path, @{ $args };

   if ($self->mode eq 'static' and '/' ne substr $path, -1, 1) {
      $path or $path = 'index';
      $path = $self->base.$self->locale."/${path}.html";
   }
   else { first_char $path ne '/' and $path = $self->base.$path }

   my $uri = bless \$path, 'URI::'.$self->scheme;

   $query_params[ 0 ] and $uri->query_form( @query_params );

   return $uri;
}

# Private methods
sub _decode_array {
   my ($self, $param) = @_; my $enc = $self->encoding;

   (not defined $param->[ 0 ] or blessed $param->[ 0 ]) and return;

   for (my $i = 0, my $len = @{ $param }; $i < $len; $i++) {
      $param->[ $i ] = decode( $enc, $param->[ $i ] );
   }

   return;
}

sub _decode_hash {
   my ($self, $param) = @_; my $enc = $self->encoding;

   for my $k (keys %{ $param }) {
      if (is_arrayref $param->{ $k }) {
         $param->{ decode( $enc, $k ) }
            = [ map { decode( $enc, $_ ) } @{ $param->{ $k } } ];
      }
      else { $param->{ decode( $enc, $k ) } = decode( $enc, $param->{ $k } ) }
   }

   return;
}

sub _get_scrubbed_param {
   my ($self, $params, $name, $opts) = @_; $opts = { %{ $opts // {} } };

   $opts->{max_length} //= $self->config->max_asset_size;
   $opts->{scrubber  } //= $self->config->scrubber;
   $opts->{multiple  } and return
      [ map { $opts->{raw} ? $_ : __scrub_value( $name, $_, $opts ) }
           @{ __get_defined_values( $params, $name, $opts ) } ];

   my $v = __get_defined_value( $params, $name, $opts );

   return $opts->{raw} ? $v : __scrub_value( $name, $v, $opts );
}

# Private functions
sub __defined_or_throw {
   my ($k, $v, $opts) = @_;

   defined $k or throw class => Unspecified, args => [ 'parameter name' ],
                          rv => HTTP_INTERNAL_SERVER_ERROR, level => 5;

   $opts->{optional} or defined $v
      or throw class => Unspecified, args => [ $k ],
                  rv => HTTP_EXPECTATION_FAILED, level => 5;
   return $v;
}

sub __get_defined_value {
   my ($params, $name, $opts) = @_;

   my $v = __defined_or_throw( $name, $params->{ $name }, $opts );

   is_arrayref $v and $v = $v->[ 0 ];

   return __defined_or_throw( $name, $v, $opts );
}

sub __get_defined_values {
   my ($params, $name, $opts) = @_;

   my $v = __defined_or_throw( $name, $params->{ $name }, $opts );

   is_arrayref $v or $v = [ $v ];

   return $v;
}

sub __scrub_value {
   my ($name, $v, $opts) = @_; my $pattern = $opts->{scrubber}; my $len;

   $pattern and defined $v and $v =~ s{ $pattern }{}gmx;

   $opts->{optional} or $opts->{allow_null} or $len = length $v
      or  throw class => Unspecified, args => [ $name ], level => 4,
                   rv => HTTP_EXPECTATION_FAILED;

   $len and $len > $opts->{max_length}
      and throw error => 'Parameter [_1] size [_2] too big',
                 args => [ $name, $len ], level => 4,
                   rv => HTTP_REQUEST_ENTITY_TOO_LARGE;
   return $v;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Doh::Request - Represents the request sent from the client to the server

=head1 Synopsis

   use Doh::Request;

   my $req = App::Doh::Request->new( $class_usul_object_ref, @args );

=head1 Description

Creates an immutable object that combines the request parameters and
the L<Plack> environment. Supplies all information about the current
request to the rest of the application (that would be the model and
the view)

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<args>

An array reference of the arguments supplied with the URI

=item C<base>

A non empty simple string which is the base of the requested URI

=item C<body>

An L<HTTP::Body> object constructed from the current request

=item C<content_length>

Length in bytes of the not yet decoded body content

=item C<content_type>

Mime type of the body content

=item C<domain>

A non empty simple string which is the domain of the request. The value of
C<host> but without the port number

=item C<encoding>

The encoding used to decode all inputs, defaults to C<UTF-8>

=item C<host>

The domain name and port number of the request

=item C<locale>

The language requested by the client. Defaults to the C<LANG> constant
C<en> (for English)

=item C<method>

The HTTP request method. Lower cased

=item C<path>

Taken from the request path, this should be the same as the
C<mount_point> configuration attribute

=item C<query>

The query parameters from the current request

=item C<scheme>

The HTTP protocol used in the request. Defaults to C<http>

=item C<script>

The request path

=item C<session>

Stores the user preferences. An instance of L<App::Doh::Session>

=item C<tunnel_method>

The C<_method> attribute from the body of a post or from the query parameters
in the event of a get request

=item C<uri>

The URI of the current request. Does not include the query parameters

=item C<username>

The name of the authenticated user. Defaults to C<unknown> if the user
is anonymous

=item C<_content>

A decoded string of characters representing the body of the request

=item C<_env>

A hash reference, the L<Plack> request environment

=item C<_params>

A hash reference of query parameters supplied with the request URI

=item C<_usul>

A copy of the L<Class::Usul> object. Required, handles C<config>, C<l10n>,
and C<log>

=back

=head1 Subroutines/Methods

=head2 C<BUILDARGS>

Picks the request parameters and environment apart. Returns the hash reference
used to instantiate the request object

=head2 C<BUILD>

Logs the request at the debug level

=head2 C<body_params>

   $code_ref = $self->body_params;

Returns a code reference which when called with a body parameter name returns
the body parameter value after first scrubbing it of "dodgy" characters. Throws
if the value is undefined or tainted

=head2 C<loc>

   $localised_string = $self->loc( $key, @args );

Translates C<$key> into the required language and substitutes the bind values.
The C<locale> is currently set in configuration but will be extracted from
the request in a future release

=head2 C<loc_default>

Like the C<loc> method but always translates to the default language

=head2 C<mode>

The mode of the current request. Set to C<online> if this is a live request,
set to C<static> of this request is generating a static page

=head2 C<query_params>

   $code_ref = $self->query_params;

Returns a code reference which when called with a query parameter name returns
the query parameter value after first scrubbing it of "dodgy" characters. Throws
if the value is undefined or tainted

=head2 C<uri_for>

   $uri_obj = $self->uri_for( $partial_uri_path, $args, $query_params );

Prefixes C<$partial_uri_path> with the base of the current request. Returns
an absolute URI

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<CGI::Simple::Cookie>

=item L<Class::Usul>

=item L<Moo>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=Doh.
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
