# @(#)Ident: Doh.pm 2013-07-20 22:12 pjf ;

package Doh;

use 5.01;
use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 11 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Functions  qw( is_arrayref is_hashref );
use Class::Usul::Types      qw( NonEmptySimpleStr Object );
use Moo;

has 'language'  => is => 'ro',   isa => NonEmptySimpleStr, default => LANG;

# Private attributes
has '_usul'     => is => 'ro', isa => Object,
   handles      => [ qw( config localize log ) ],
   init_arg     => 'builder', required => TRUE, weak_ref => TRUE;

sub loc {
   my ($self, $key, @args) = @_; my $car = $args[ 0 ];

   my $args = (is_hashref $car) ? { %{ $car } }
            : { params => (is_arrayref $car) ? $car : [ @args ] };

   $args->{domain_names} ||= [ DEFAULT_L10N_DOMAIN, $self->config->name ];
   $args->{locale      } ||= $self->language;

   return $self->localize( $key, $args );
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Doh - One-line description of the modules purpose

=head1 Synopsis

   use Doh;
   # Brief but working code examples

=head1 Version

This documents version v0.1.$Rev: 11 $ of L<Doh>

=head1 Description

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<language>

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

There are no known bugs in this module.
Please report problems to the address below.
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
