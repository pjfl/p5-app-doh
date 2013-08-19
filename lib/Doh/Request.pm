# @(#)Ident: Request.pm 2013-08-19 11:12 pjf ;

package Doh::Request;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 17 $ =~ /\d+/gmx );

use CGI::Simple::Cookie;
use Class::Usul::Constants;
use Class::Usul::Functions qw( is_hashref trim );
use Class::Usul::Types     qw( ArrayRef HashRef NonEmptySimpleStr );
use Moo;

has 'args'   => is => 'ro', isa => ArrayRef, default => sub { [] };

has 'base'   => is => 'ro', isa => NonEmptySimpleStr, required => TRUE;

has 'cookie' => is => 'ro', isa => HashRef, default => sub { {} };

has 'domain' => is => 'ro', isa => NonEmptySimpleStr, required => TRUE;

has 'env'    => is => 'ro', isa => HashRef, default => sub { {} };

has 'params' => is => 'ro', isa => HashRef, default => sub { {} };

around 'BUILDARGS' => sub {
   my $orig = shift; my $self = shift; my $attr = {};

   my $env = ( $_[ -1 ] && is_hashref $_[ -1 ] ) ? pop @_ : {};

   $attr->{env   } = $env;
   $attr->{params} = ( $_[ -1 ] && is_hashref $_[ -1 ] ) ? pop @_ : {};
   $attr->{args  } = [ split m{ [/] }mx, trim $_[  0 ] || NUL, '/' ];
   $attr->{base  } = $env->{SCRIPT_NAME} || '/';
   $attr->{cookie} = { CGI::Simple::Cookie->parse( $env->{HTTP_COOKIE} ) };
   $attr->{domain} = (split m{ [:] }mx, $env->{HTTP_HOST})[ 0 ];
   return $attr;
};

1;

__END__

=pod

=encoding utf8

=head1 Name

Doh::Request - One-line description of the modules purpose

=head1 Synopsis

   use Doh::Request;
   # Brief but working code examples

=head1 Version

This documents version v0.1.$Rev: 17 $ of L<Doh::Request>

=head1 Description

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=back

=head1 Subroutines/Methods

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Usul>

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
