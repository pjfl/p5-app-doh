# @(#)Ident: Request.pm 2013-09-05 11:16 pjf ;

package App::Doh::Request;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 19 $ =~ /\d+/gmx );

use CGI::Simple::Cookie;
use Class::Usul::Constants;
use Class::Usul::Functions qw( is_hashref trim );
use Class::Usul::Types     qw( ArrayRef HashRef NonEmptySimpleStr SimpleStr );
use Moo;

has 'args'   => is => 'ro', isa => ArrayRef, default => sub { [] };

has 'base'   => is => 'ro', isa => NonEmptySimpleStr, required => TRUE;

has 'cookie' => is => 'ro', isa => HashRef, default => sub { {} };

has 'domain' => is => 'ro', isa => NonEmptySimpleStr, required => TRUE;

has 'env'    => is => 'ro', isa => HashRef, default => sub { {} };

has 'params' => is => 'ro', isa => HashRef, default => sub { {} };

has 'path'   => is => 'ro', isa => SimpleStr, default => NUL;

around 'BUILDARGS' => sub {
   my ($orig, $self, @args) = @_; my $attr = {};

   my $env  = ($args[ -1 ] && is_hashref $args[ -1 ]) ? pop @args : {};
   my $prot = lc( (split m{ / }mx, $env->{SERVER_PROTOCOL} || 'HTTP')[ 0 ] );
   my $path = $env->{SCRIPT_NAME} || '/'; $path =~ s{ / \z }{}gmx;
   my $host = $env->{HTTP_HOST} || 'localhost';

   $attr->{env   } = $env;
   $attr->{params} = ($args[ -1 ] && is_hashref $args[ -1 ]) ? pop @args : {};
   $attr->{args  } = [ split m{ / }mx, trim $args[ 0 ] || NUL ];
   $attr->{base  } = $prot.'://'.$host.$path.'/';
   $attr->{cookie} = { CGI::Simple::Cookie->parse( $env->{HTTP_COOKIE} ) };
   $attr->{domain} = (split m{ : }mx, $host)[ 0 ];
   $attr->{path  } = $path;
   return $attr;
};

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
   # Brief but working code examples

=head1 Version

This documents version v0.1.$Rev: 19 $ of L<Doh::Request>

=head1 Description

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<args>

An array ref of the args supplied with the URI

=item C<base>

A non empty simple string which is the base of the requested URI

=item C<cookie>

A hash ref of cookies supplied with the request

=item C<domain>

A non empty simple string which is the domain of the request

=item C<env>

A hash ref, the L<Plack> request env

=item C<params>

A hash ref of parameters supplied with the request

=item C<path>

Taken from the request path, this should be the same as the
C<mount_point> configuration attribute

=back

=head1 Subroutines/Methods

None

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
