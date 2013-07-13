# @(#)Ident: perl_module.pm 2013-07-06 14:16 pjf ;

package Daux;

use 5.01;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 1 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Functions  qw( throw );
use Moo;

extends qw(Class::Usul::Programs);

1;

__END__

=pod

=encoding utf8

=head1 Name

Daux - One-line description of the modules purpose

=head1 Synopsis

   use Daux;
   # Brief but working code examples

=head1 Version

This documents version v0.1.$Rev: 1 $ of L<Daux>

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
