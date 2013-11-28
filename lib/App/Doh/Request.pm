# @(#)Ident: Request.pm 2013-11-28 17:15 pjf ;

package App::Doh::Request;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 23 $ =~ /\d+/gmx );

use Moo;
use CGI::Simple::Cookie;
use Class::Usul::Constants;
use Class::Usul::Functions qw( is_arrayref is_hashref trim );
use Class::Usul::Types     qw( ArrayRef HashRef NonEmptySimpleStr
                               Object SimpleStr );

extends q(App::Doh);

has 'args'   => is => 'ro', isa => ArrayRef, default => sub { [] };

has 'base'   => is => 'ro', isa => NonEmptySimpleStr, required => TRUE;

has 'cookie' => is => 'ro', isa => HashRef, default => sub { {} };

has 'domain' => is => 'ro', isa => NonEmptySimpleStr, required => TRUE;

has 'env'    => is => 'ro', isa => HashRef, default => sub { {} };

has 'locale' => is => 'ro', isa => NonEmptySimpleStr, default => LANG;

has 'params' => is => 'ro', isa => HashRef, default => sub { {} };

has 'path'   => is => 'ro', isa => SimpleStr, default => NUL;

around 'BUILDARGS' => sub {
   my ($orig, $self, @args) = @_; my $attr = {};

   my $usul = shift @args;
   my $env  = ($args[ -1 ] && is_hashref $args[ -1 ]) ? pop @args : {};
   my $prot = lc( (split m{ / }mx, $env->{SERVER_PROTOCOL} || 'HTTP')[ 0 ] );
   my $path = $env->{SCRIPT_NAME} || '/'; $path =~ s{ / \z }{}gmx;
   my $host = $env->{HTTP_HOST} || 'localhost';

   $attr->{builder} = $usul;
   $attr->{env    } = $env;
   $attr->{params } = ($args[ -1 ] && is_hashref $args[ -1 ]) ? pop @args : {};
   $attr->{args   } = [ split m{ / }mx, trim $args[ 0 ] || NUL ];
   $attr->{base   } = $prot.'://'.$host.$path.'/';
   $attr->{cookie } = { CGI::Simple::Cookie->parse( $env->{HTTP_COOKIE} ) };
   $attr->{domain } = (split m{ : }mx, $host)[ 0 ];
   $attr->{path   } = $path;
   $attr->{locale } = $usul->config->locale; # TODO: Make request dependent
   return $attr;
};

sub loc {
   my ($self, $key, @args) = @_; my $car = $args[ 0 ];

   my $args = (is_hashref $car) ? { %{ $car } }
            : { params => (is_arrayref $car) ? $car : [ @args ] };

   $args->{domain_names} ||= [ DEFAULT_L10N_DOMAIN, $self->config->name ];
   $args->{locale      } ||= $self->locale;

   return $self->localize( $key, $args );
}

sub uri_for {
   my ($self, $args) = @_; return $self->base.$args;
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

=head1 Version

This documents version v0.1.$Rev: 23 $ of L<Doh::Request>

=head1 Description

Creates an object that combines the request parameters and the L<Plack>
environment. Supplies all information about the current request to the
rest of the application (that would be the model and the view)

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<args>

An array reference of the arguments supplied with the URI

=item C<base>

A non empty simple string which is the base of the requested URI

=item C<cookie>

A hash reference of cookies supplied with the request

=item C<domain>

A non empty simple string which is the domain of the request

=item C<env>

A hash reference, the L<Plack> request environment

=item C<locale>

Defaults to the C<LANG> constant C<en> (for english)

=item C<params>

A hash reference of query parameters supplied with the request URI

=item C<path>

Taken from the request path, this should be the same as the
C<mount_point> configuration attribute

=back

=head1 Subroutines/Methods

=head2 loc

   $localised_string = $self->loc( $key, @args );

Translates C<$key> into the required language and substitutes the bind values.
The C<locale> is currently set in configuration but will be extracted from
the request in a future release

=head2 uri_for

   $uri_obj = $self->uri_for( $partial_uri_path );

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

Copyright (c) 2013 Peter Flanigan. All rights reserved

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
