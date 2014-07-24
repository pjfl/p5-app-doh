package App::Doh::Request;

use namespace::autoclean;

use Moo;
use App::Doh::Functions    qw( extract_lang );
use App::Doh::Session;
use Class::Usul::Constants qw( EXCEPTION_CLASS FALSE NUL SPC TRUE );
use Class::Usul::Functions qw( first_char is_arrayref is_hashref
                               is_member throw trim );
use Class::Usul::Types     qw( ArrayRef BaseType Bool HashRef NonEmptySimpleStr
                               Object SimpleStr );
use Encode                 qw( decode );
use HTTP::Body;
use HTTP::Status           qw( HTTP_EXPECTATION_FAILED
                               HTTP_INTERNAL_SERVER_ERROR );
use Scalar::Util           qw( blessed weaken );
use Unexpected::Functions  qw( Unspecified );
use URI::http;
use URI::https;

has 'args'     => is => 'ro',   isa => ArrayRef, default => sub { [] };

has 'base'     => is => 'lazy', isa => Object;

has 'body'     => is => 'lazy', isa => Object;

has 'domain'   => is => 'lazy', isa => NonEmptySimpleStr,
   builder     => sub { (split m{ : }mx, $_[ 0 ]->host)[ 0 ] };

has 'env'      => is => 'ro',   isa => HashRef, default => sub { {} };

has 'host'     => is => 'lazy', isa => NonEmptySimpleStr, builder => sub {
   my $env     =  $_[ 0 ]->env;
      $env->{ 'HTTP_HOST' } // $env->{ 'SERVER_NAME' } // 'localhost' };

has 'language' => is => 'lazy', isa => NonEmptySimpleStr,
   builder     => sub { extract_lang $_[ 0 ]->locale };

has 'locale'   => is => 'lazy', isa => NonEmptySimpleStr;

has 'locales'  => is => 'lazy', isa => ArrayRef;

has 'method'   => is => 'lazy', isa => SimpleStr,
   builder     => sub { lc( $_[ 0 ]->env->{ 'REQUEST_METHOD' } // NUL ) };

has 'params'   => is => 'ro',   isa => HashRef, default => sub { {} };

has 'path'     => is => 'lazy', isa => SimpleStr, builder => sub {
   my $v       =  $_[ 0 ]->env->{ 'PATH_INFO' } // '/';
      $v       =~ s{ \A / }{}mx; $v =~ s{ \? .* \z }{}mx; $v };

has 'query'    => is => 'lazy', isa => SimpleStr, builder => sub {
   my $v       =  $_[ 0 ]->env->{ 'QUERY_STRING' }; $v ? "'?${v}" : NUL };

has 'scheme'   => is => 'lazy', isa => NonEmptySimpleStr,
   builder     => sub { $_[ 0 ]->env->{ 'psgi.url_scheme' } // 'http' };

has 'script'   => is => 'lazy', isa => SimpleStr, builder => sub {
   my $v       =  $_[ 0 ]->env->{ 'SCRIPT_NAME' } // '/';
      $v       =~ s{ / \z }{}gmx; $v };

has 'session'  => is => 'lazy', isa => Object, builder => sub {
   App::Doh::Session->new( builder => $_[ 0 ]->usul, env => $_[ 0 ]->env ) },
   handles     => [ qw( authenticated username ) ];

has 'uri'      => is => 'lazy', isa => Object;

has 'usul'     => is => 'ro',   isa => BaseType,
   handles     => [ qw( config l10n log ) ], init_arg => 'builder',
   required    => TRUE;

has 'tunnel_method' => is => 'lazy', isa => NonEmptySimpleStr, builder => sub {
   my $body_method  = delete $_[ 0 ]->body->param->{_method};
   my $param_method = delete $_[ 0 ]->params->{_method};
   my $method       = $body_method || $param_method || 'not_found';
   (is_arrayref $method) ? $method->[ 0 ] : $method };

# Construction
around 'BUILDARGS' => sub {
   my ($orig, $self, @args) = @_; my $attr = {};

   $attr->{builder} = shift @args;
   $attr->{env    } = (is_hashref $args[ -1 ]) ? pop @args : {};
   $attr->{params } = (is_hashref $args[ -1 ]) ? pop @args : {};
   $attr->{args   } = (defined $args[ 0 ] && blessed $args[ 0 ])
                    ? [ $args[ 0 ] ]
                    : [ split m{ / }mx, trim $args[ 0 ] || NUL ];

   return $attr;
};

sub BUILD {
   my $self = shift; $self->tunnel_method; # Coz it's destructive

   my $mode = $self->params->{mode} // 'online';

   $mode ne 'static' and $self->log->debug
      ( join SPC, (uc $self->method), $self->uri,
        ($self->authenticated ? $self->username : NUL) );

   return;
}

sub _build_base {
   my $self = shift; my $params = $self->params; my $uri;

   if (exists $params->{mode} and $params->{mode} eq 'static') {
      my @path = split m{ / }mx, $self->path; $uri = '../' x scalar @path;
   }
   else { $uri = $self->scheme.'://'.$self->host.$self->script.'/' }

   return bless \$uri, 'URI::'.$self->scheme;
}

sub _build_body {
   my $self = shift; my $env = $self->env; my $content = NUL;

   $env->{CONTENT_LENGTH}
      and $env->{ 'psgi.input' }->read( $content, $env->{CONTENT_LENGTH} );

   my $body = HTTP::Body->new( $env->{CONTENT_TYPE}, length $content );

   length $content and $body->add( $content );

   for my $k (keys %{ $body->param }) {
      if (is_arrayref $body->param->{ $k }) {
         $body->param->{ $k } = [ map { decode( 'UTF-8', $_  ) }
                                     @{ $body->param->{ $k } } ];
      }
      else { $body->param->{ $k } = decode( 'UTF-8', $body->param->{ $k } ) }
   }

   return $body;
}

sub _build_locale {
   my $self = shift; my $locale;

   exists $self->params->{locale}
      and defined  ($locale = $self->params->{locale})
      and is_member $locale,  $self->config->locales
      and return $locale;

   for my $locale (@{ $self->locales }) {
      is_member $locale, $self->config->locales and return $locale;
   }

   return $self->config->locale;
}

sub _build_locales {
   my $self = shift; my $lang = $self->env->{ 'HTTP_ACCEPT_LANGUAGE' } || NUL;

   return [ map    { s{ _ \z }{}mx; $_ }
            map    { join '_', $_->[ 0 ], uc $_->[ 1 ] }
            map    { [ split m{ - }mx, $_ ] }
            map    { ( split m{ ; }mx, $_ )[ 0 ] }
            split m{ , }mx, lc $lang ];
}

sub _build_uri {
   my $self = shift; my $params = $self->params; my $uri;

   if (exists $params->{mode} and $params->{mode} eq 'static') {
      $uri = $self->base.$self->locale.'/'.$self->path.'.html';
   }
   else { $uri = $self->base.$self->path }

   return bless \$uri, 'URI::'.$self->scheme;
}

# Public methods
sub body_params {
   my $self = shift; my $pattern = $self->config->scrubber;

   my $params = $self->body->param; weaken( $params );

   return sub { __get_scrubbed_value( $pattern, $params, @_ ) };
}

sub body_value {
   my $self = shift; return __get_defined_value( $self->body->param, @_ );
}

sub body_values {
   my $self = shift; return __get_defined_values( $self->body->param, @_ );
}

sub loc {
   my $self = shift; return $self->l10n->localizer( $self->locale, @_ );
}

sub loc_default {
   my $self = shift; return $self->l10n->localizer( $self->config->locale, @_ );
}

sub query_params {
   my $self = shift; my $pattern = $self->config->scrubber;

   my $params = $self->params; weaken( $params );

   return sub { __get_scrubbed_value( $pattern, $params, @_ ) };
}

sub uri_for {
   my ($self, $path, $args, @query_params) = @_; my $params = $self->params;

   $args and defined $args->[ 0 ] and $path = join '/', $path, @{ $args };

   if (exists $params->{mode}
          and $params->{mode} eq 'static' and '/' ne substr $path, -1, 1) {
      $path or $path = 'index';
      $path = $self->base.$self->locale."/${path}.html";
   }
   else { first_char $path ne '/' and $path = $self->base.$path }

   my $uri = bless \$path, 'URI::'.$self->scheme;

   $query_params[ 0 ] and $uri->query_form( @query_params );

   return $uri;
}

# Private functions
sub __defined_or_throw {
   defined $_[ 0 ] or throw class => Unspecified, args => [ 'parameter name' ],
                               rv => HTTP_INTERNAL_SERVER_ERROR, level => 5;
   defined $_[ 1 ] or throw class => Unspecified, args => [ $_[ 0 ] ],
                               rv => HTTP_EXPECTATION_FAILED, level => 5;
   return $_[ 1 ];
}

sub __get_defined_value {
   my ($params, $name) = @_;

   my $v = __defined_or_throw( $name, $params->{ $name } );

   is_arrayref $v and $v = $v->[ 0 ];

   return __defined_or_throw( $name, $v );
}

sub __get_defined_values {
   my ($params, $name) = @_;

   my $v = __defined_or_throw( $name, $params->{ $name } );

   is_arrayref $v or $v = [ $v ];

   return $v;
}

sub __get_scrubbed_value {
   my ($pattern, $params, $name, $opts) = @_; $opts //= {};

   my $v = __get_defined_value( $params, $name );

   $pattern = $opts->{scrubber} // $pattern;
   $pattern and $v =~ s{ $pattern }{}gmx;
   $opts->{allow_null} or length $v
      or throw class => Unspecified, args => [ $name ], level => 3,
                  rv => HTTP_EXPECTATION_FAILED;
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

=item C<domain>

A non empty simple string which is the domain of the request. The value of
C<host> but without the port number

=item C<env>

A hash reference, the L<Plack> request environment

=item C<host>

The domain name and port number of the request

=item C<locale>

The language requested by the client. Defaults to the C<LANG> constant
C<en> (for English)

=item C<method>

The HTTP request method. Lower cased

=item C<params>

A hash reference of query parameters supplied with the request URI

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

=item C<usul>

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

=head2 C<body_value>

   $value = $self->body_value( $name );

Returns the named body value, throws if the value is not defined. Returns the
first value if the body contains more than one

=head2 C<body_values>

   $array_ref_values = $self->body_values( $name );

Returns the named body values, throws if the values are not defined

=head2 C<loc>

   $localised_string = $self->loc( $key, @args );

Translates C<$key> into the required language and substitutes the bind values.
The C<locale> is currently set in configuration but will be extracted from
the request in a future release

=head2 C<loc_default>

Like the C<loc> method but always translates to the default language

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
