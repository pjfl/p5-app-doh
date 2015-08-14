package App::Doh::Request;

use namespace::autoclean;

use App::Doh::Functions    qw( extract_lang new_uri );
use Class::Usul::Constants qw( EXCEPTION_CLASS NUL SPC TRUE );
use Class::Usul::Functions qw( first_char is_arrayref
                               is_hashref is_member throw trim );
use Class::Usul::Types     qw( ArrayRef BaseType HashRef LoadableClass
                               NonEmptySimpleStr Object PositiveInt
                               SimpleStr Str );
use Encode                 qw( decode );
use HTTP::Body;
use HTTP::Status           qw( HTTP_EXPECTATION_FAILED
                               HTTP_INTERNAL_SERVER_ERROR
                               HTTP_REQUEST_ENTITY_TOO_LARGE );
use Scalar::Util           qw( blessed weaken );
use Try::Tiny;
use Unexpected::Functions  qw( Unspecified );
use Moo;

# Private methods
my $_decode_array = sub {
   my ($self, $param) = @_; my $enc = $self->encoding;

   (not defined $param->[ 0 ] or blessed $param->[ 0 ]) and return;

   for (my $i = 0, my $len = @{ $param }; $i < $len; $i++) {
      $param->[ $i ] = decode( $enc, $param->[ $i ] );
   }

   return;
};

my $_decode_hash = sub {
   my ($self, $param) = @_; my $enc = $self->encoding;

   for my $k (keys %{ $param }) {
      if (is_arrayref $param->{ $k }) {
         $param->{ decode( $enc, $k ) }
            = [ map { decode( $enc, $_ ) } @{ $param->{ $k } } ];
      }
      else { $param->{ decode( $enc, $k ) } = decode( $enc, $param->{ $k } ) }
   }

   return;
};

# Attribute constructors
my $_build__base = sub {
   my $self = shift;

   return $self->mode eq 'static'
        ? '../' x scalar split m{ / }mx, $self->path
        : $self->scheme.'://'.$self->hostport.$self->script.'/';
};

my $_build_body = sub {
   my $self = shift; my $env = $self->_env; my $content = $self->_content;

   my $body = HTTP::Body->new( $self->content_type, length $content );

   length $content and $body->add( $content );
   $self->$_decode_hash( $body->param );
   return $body;
};

my $_build__content = sub {
   my $self = shift; my $env = $self->_env; my $content;

   my $cl = $self->content_length  or return NUL;
   my $fh = $env->{ 'psgi.input' } or return NUL;

   try   { $fh->seek( 0, 0 ); $fh->read( $content, $cl, 0 ); $fh->seek( 0, 0 ) }
   catch { $self->log->error( $_ ); $content = NUL };

   return $content || NUL;
};

my $_build_locale = sub {
   my $self   = shift;
   my $locale = $self->query_params( 'locale', { optional => TRUE } );

   $locale and is_member $locale, $self->config->locales and return $locale;

   for (@{ $self->locales }) {
      is_member $_, $self->config->locales and return $_;
   }

   return $self->config->locale;
};

my $_build_locales = sub {
   my $self = shift; my $lang = $self->_env->{ 'HTTP_ACCEPT_LANGUAGE' } // NUL;

   return [ map    { s{ _ \z }{}mx; $_ }
            map    { join '_', $_->[ 0 ], uc( $_->[ 1 ] // NUL ) }
            map    { [ split m{ - }mx, $_ ] }
            map    { ( split m{ ; }mx, $_ )[ 0 ] }
            split m{ , }mx, lc $lang ];
};

my $_build_tunnel_method = sub {
   return $_[ 0 ]->body_params->(  '_method', { optional => TRUE } )
       || $_[ 0 ]->query_params->( '_method', { optional => TRUE } )
       || 'not_found';
};

my $_build_uri = sub {
   my $self = shift;
   my $path = $self->mode ne 'static'
            ? $self->path : $self->locale.'/'.$self->path.'.html';

   return new_uri $self->_base.$path, $self->scheme;
};

# Public attributes
has 'args'           => is => 'ro',   isa => ArrayRef, builder => sub { [] };

has 'base'           => is => 'lazy', isa => Object,
   builder           => sub { new_uri $_[ 0 ]->_base, $_[ 0 ]->scheme },
   init_arg          => undef;

has 'body'           => is => 'lazy', isa => Object, builder => $_build_body;

has 'content_length' => is => 'lazy', isa => PositiveInt,
   builder           => sub { $_[ 0 ]->_env->{ 'CONTENT_LENGTH' } // 0 };

has 'content_type'   => is => 'lazy', isa => SimpleStr,
   builder           => sub { $_[ 0 ]->_env->{ 'CONTENT_TYPE' } // NUL };

has 'domain'         => is => 'lazy', isa => NonEmptySimpleStr,
   builder           => sub { $_[ 0 ]->config->name };

has 'encoding'       => is => 'lazy', isa => NonEmptySimpleStr,
   builder           => sub { $_[ 0 ]->config->encoding };

has 'host'           => is => 'lazy', isa => NonEmptySimpleStr,
   builder           => sub { (split m{ : }mx, $_[ 0 ]->hostport)[ 0 ] };

has 'hostport'       => is => 'lazy', isa => NonEmptySimpleStr,
   builder           => sub { $_[ 0 ]->_env->{ 'HTTP_HOST' } // 'localhost' };

has 'language'       => is => 'lazy', isa => NonEmptySimpleStr,
   builder           => sub { extract_lang $_[ 0 ]->locale };

has 'locale'         => is => 'lazy', isa => NonEmptySimpleStr,
   builder           => $_build_locale;

has 'locales'        => is => 'lazy', isa => ArrayRef,
   builder           => $_build_locales;

has 'method'         => is => 'lazy', isa => SimpleStr,
   builder           => sub { lc( $_[ 0 ]->_env->{ 'REQUEST_METHOD' } // NUL )};

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

has 'session'        => is => 'lazy', isa => Object,
   builder           => sub { $_[ 0 ]->session_class->new
                                 ( builder => $_[ 0 ]->_usul,
                                   env     => $_[ 0 ]->_env ) },
   handles           => [ qw( authenticated username ) ];

has 'session_class'  => is => 'lazy', isa => LoadableClass,
   default           => 'App::Doh::Session';

has 'tunnel_method'  => is => 'lazy', isa => NonEmptySimpleStr,
   builder           => $_build_tunnel_method;

has 'uri'            => is => 'lazy', isa => Object, builder => $_build_uri;

# Private attributes
has '_base'    => is => 'lazy', isa => NonEmptySimpleStr,
   builder     => $_build__base, init_arg => undef;

has '_content' => is => 'lazy', isa => Str,
   builder     => $_build__content, init_arg => undef;

has '_env'     => is => 'ro',   isa => HashRef,
   builder     => sub { {} }, init_arg => 'env';

has '_params'  => is => 'ro',   isa => HashRef,
   builder     => sub { {} }, init_arg => 'params';

has '_usul'    => is => 'ro',   isa => BaseType, required => TRUE,
   handles     => [ qw( config l10n log ) ], init_arg => 'builder';

# Construction
around 'BUILDARGS' => sub {
   my ($orig, $self, $attr, @args) = @_; @args == 0 and return $attr;

   $attr->{env   } = ($args[ 0 ] and is_hashref $args[ -1 ]) ? pop @args : {};
   $attr->{params} = ($args[ 0 ] and is_hashref $args[ -1 ]) ? pop @args : {};
   $attr->{args  } = (defined $args[ 0 ] && blessed $args[ 0 ])
                   ? [ $args[ 0 ] ] # Upload object
                   : [ split m{ / }mx, trim $args[ 0 ] || NUL ];

   return $attr;
};

sub BUILD {
   my $self = shift;

   $self->$_decode_array( $self->args ); $self->$_decode_hash( $self->_params );

   $self->mode ne 'static' and $self->log->debug
      ( join SPC, (uc $self->method), $self->uri,
        ($self->authenticated ? $self->username : NUL) );
   return;
}

# Private functions
my $_defined_or_throw = sub {
   my ($k, $v, $opts) = @_; $k =~ m{ \A \d+ \z }mx and $k = "arg[${k}]";

   $opts->{optional} or defined $v
      or throw 'Parameter [_1] undefined value', [ $k ],
               level => 6, rv => HTTP_EXPECTATION_FAILED;

   return $v;
};

my $_get_last_value = sub {
   my ($k, $v, $opts) = @_; return $_defined_or_throw->( $k, $v->[-1], $opts );
};

my $_get_value_or_values = sub {
   my ($params, $name, $opts) = @_;

   defined $name or throw Unspecified, [ 'name' ],
                          level => 5, rv => HTTP_INTERNAL_SERVER_ERROR;

   my $v = (is_arrayref $params) ? $params->[ $name ] : $params->{ $name };

   return $_defined_or_throw->( $name, $v, $opts );
};

my $_get_defined_value = sub {
   my ($params, $name, $opts) = @_;

   my $v = $_get_value_or_values->( $params, $name, $opts );

   return (is_arrayref $v) ? $_get_last_value->( $name, $v, $opts ) : $v;
};

my $_get_defined_values = sub {
   my ($params, $name, $opts) = @_;

   my $v = $_get_value_or_values->( $params, $name, $opts );

   return (is_arrayref $v) ? $v : [ $v ];
};

my $_scrub_value = sub {
   my ($name, $v, $opts) = @_; my $pattern = $opts->{scrubber}; my $len;

   $pattern and defined $v and $v =~ s{ $pattern }{}gmx;

   $opts->{optional} or $opts->{allow_null} or $len = length $v
      or  throw Unspecified, [ $name ], level => 4,
                rv => HTTP_EXPECTATION_FAILED;

   $name =~ m{ \A \d+ \z }mx and $name = "arg[${name}]";

   $len and $len > $opts->{max_length}
      and throw 'Parameter [_1] size [_2] too big', [ $name, $len ], level => 4,
                rv => HTTP_REQUEST_ENTITY_TOO_LARGE;
   return $v;
};

my $_get_scrubbed_param = sub {
   my ($self, $params, $name, $opts) = @_; $opts = { %{ $opts // {} } };

   $opts->{max_length} //= $self->config->max_asset_size;
   $opts->{scrubber  } //= $self->config->scrubber;
   $opts->{multiple  } and return
      [ map { $opts->{raw} ? $_ : $_scrub_value->( $name, $_, $opts ) }
           @{ $_get_defined_values->( $params, $name, $opts ) } ];

   my $v = $_get_defined_value->( $params, $name, $opts );

   return $opts->{raw} ? $v : $_scrub_value->( $name, $v, $opts );
};

# Public methods
sub args_params {
   my $self = shift; weaken( $self );

   my $params = $self->args; weaken( $params );

   return sub { $_get_scrubbed_param->( $self, $params, @_ ) };
}

sub body_params {
   my $self = shift; weaken( $self );

   my $params = $self->body->param; weaken( $params );

   return sub { $_get_scrubbed_param->( $self, $params, @_ ) };
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

   return sub { $_get_scrubbed_param->( $self, $params, @_ ) };
}

sub uri_for {
   my ($self, $path, $args, @query_params) = @_;

   $args and defined $args->[ 0 ] and $path = join '/', $path, @{ $args };

   if ($self->mode eq 'static' and '/' ne substr $path, -1, 1) {
      $path or $path = 'index';
      $path = $self->_base.$self->locale."/${path}.html";
   }
   else { first_char $path ne '/' and $path = $self->_base.$path }

   my $uri = new_uri $path, $self->scheme;

   $query_params[ 0 ] and $uri->query_form( @query_params );

   return $uri;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Doh::Request - Represents the request sent from the client to the server

=head1 Synopsis

   use Doh::Request;

   my $req = App::Doh::Request->new( $class_usul_ref, $model_moniker, @args );

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

The domain to which this request belongs. Can be used to select assets like
translation files

=item C<host>

A non empty simple string which is the hostname in the request. The value of
L</hostport> but without the port number

=item C<encoding>

The encoding used to decode all inputs, defaults to C<UTF-8>

=item C<hostport>

The hostname and port number in the request

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
