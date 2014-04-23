package App::Doh::Request;

use namespace::sweep;

use Moo;
use Class::Usul::Constants;
use Class::Usul::Functions qw( first_char is_arrayref is_hashref
                               is_member trim );
use Class::Usul::Types     qw( ArrayRef HashRef NonEmptySimpleStr
                               Object SimpleStr );
use Encode                 qw( decode );
use HTTP::Body;
use Scalar::Util           qw( blessed );
use URI::http;
use URI::https;

extends q(App::Doh);

has 'args'     => is => 'ro',   isa => ArrayRef, default => sub { [] };

has 'base'     => is => 'lazy', isa => Object;

has 'body'     => is => 'lazy', isa => Object;

has 'domain'   => is => 'lazy', isa => NonEmptySimpleStr,
   builder     => sub { (split m{ : }mx, $_[ 0 ]->host)[ 0 ] };

has 'env'      => is => 'ro',   isa => HashRef, default => sub { {} };

has 'host'     => is => 'lazy', isa => NonEmptySimpleStr,
   builder     => sub {
      my $env  =  $_[ 0 ]->env;
         $env->{ 'HTTP_HOST' } // $env->{ 'SERVER_NAME' } // 'localhost' };

has 'locale'   => is => 'lazy', isa => NonEmptySimpleStr;

has 'method'   => is => 'lazy', isa => NonEmptySimpleStr,
   builder     => sub {
         $_[ 0 ]->body->param->{_method}
      || $_[ 0 ]->params->{_method} || 'not_found' };

has 'params'   => is => 'ro',   isa => HashRef, default => sub { {} };

has 'path'     => is => 'lazy', isa => SimpleStr,
   builder     => sub {
      my $v    =  $_[ 0 ]->env->{ 'PATH_INFO' } // '/';
         $v    =~ s{ \A / }{}mx; $v =~ s{ \? .* \z }{}mx; $v };

has 'query'    => is => 'lazy', isa => SimpleStr,
   builder     => sub {
      my $v    =  $_[ 0 ]->env->{ 'QUERY_STRING' }; $v ? "'?${v}" : NUL };

has 'scheme'   => is => 'lazy', isa => NonEmptySimpleStr,
   builder     => sub { $_[ 0 ]->env->{ 'psgi.url_scheme' } // 'http' };

has 'script'   => is => 'lazy', isa => SimpleStr,
   builder     => sub {
      my $v    =  $_[ 0 ]->env->{ 'SCRIPT_NAME' } // '/';
         $v    =~ s{ / \z }{}gmx; $v };

has 'session'  => is => 'lazy', isa => HashRef,
   builder     => sub { $_[ 0 ]->env->{ 'psgix.session' } // {} };

has 'uri'      => is => 'lazy', isa => Object;

has 'username' => is => 'lazy', isa => NonEmptySimpleStr,
   builder     => sub { $_[ 0 ]->env->{ 'REMOTE_USER' } // 'unknown' };

# Construction
around 'BUILDARGS' => sub {
   my ($orig, $self, $builder, @args) = @_; my $attr = {};

   $attr->{builder} = $builder;
   $attr->{env    } = (is_hashref $args[ -1 ]) ? pop @args : {};
   $attr->{params } = (is_hashref $args[ -1 ]) ? pop @args : {};
   $attr->{args   } = (defined $args[ 0 ] && blessed $args[ 0 ])
                    ? [ $args[ 0 ] ]
                    : [ split m{ / }mx, trim $args[ 0 ] || NUL ];

   return $attr;
};

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
      $body->param->{ $k } = decode( 'UTF-8', $body->param->{ $k } );
   }

   return $body;
}

sub _build_locale {
   my $self = shift; my $locale;

   exists $self->params->{locale}
      and defined  ($locale = $self->params->{locale})
      and is_member $locale,  $self->config->locales
      and return $locale;

   for my $locale (@{ $self->_acceptable_locales }) {
      is_member $locale, $self->config->locales and return $locale;
   }

   return $self->config->locale;
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
sub loc {
   my ($self, $key, @args) = @_;

   return $self->_localize( $self->locale, $key, @args );
}

sub loc_default {
   my ($self, $key, @args) = @_;

   return $self->_localize( $self->config->locale, $key, @args );
}

sub uri_for {
   my ($self, $path, $args, $query_params) = @_; my $params = $self->params;

   $args and defined $args->[ 0 ] and $path = join '/', $path, @{ $args };

   if (exists $params->{mode} and $params->{mode} eq 'static'
          and '/' ne substr $path, -1, 1) {
      $path or $path = 'index';
      $path = $self->base.$self->locale."/${path}.html";
   }
   else { first_char $path ne '/' and $path = $self->base.$path }

   my $uri = bless \$path, 'URI::'.$self->scheme;

   $query_params and $uri->query_form( @{ $query_params } );

   return $uri;
}

# Private methods
sub _acceptable_locales {
   my $self = shift; my $lang = $self->env->{ 'HTTP_ACCEPT_LANGUAGE' } || NUL;

   return [ map    { s{ _ \z }{}mx; $_ }
            map    { join '_', $_->[ 0 ], uc $_->[ 1 ] }
            map    { [ split m{ - }mx, $_ ] }
            map    { ( split m{ ; }mx, $_ )[ 0 ] }
            split m{ , }mx, lc $lang ];
}

sub _localize {
   my ($self, $locale, $key, @args) = @_; my $car = $args[ 0 ];

   my $args = (is_hashref $car) ? { %{ $car } }
            : { params => (is_arrayref $car) ? $car : [ @args ] };

   $args->{domain_names} ||= [ DEFAULT_L10N_DOMAIN, $self->config->name ];
   $args->{locale      } ||= $locale;

   return $self->localize( $key, $args );
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

The C<_method> attribute from the body of a post or from the query parameters
in the event of a get request

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

Stores the user preferences. A hash reference

=item C<uri>

The URI of the current request. Does not include the query parameters

=item C<username>

The name of the authenticated user. Defaults to C<unknown> if the user
is anonymous

=back

=head1 Subroutines/Methods

=head2 BUILDARGS

Picks the request parameters and environment apart. Returns the hash reference
used to instantiate the request object

=head2 loc

   $localised_string = $self->loc( $key, @args );

Translates C<$key> into the required language and substitutes the bind values.
The C<locale> is currently set in configuration but will be extracted from
the request in a future release

=head2 loc_default

Like the C<loc> method but always translates to the default language

=head2 uri_for

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
