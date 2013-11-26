# @(#)Ident: Doh.pm 2013-11-23 22:17 pjf ;

package App::Doh;

use 5.010001;
use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 22 $ =~ /\d+/gmx );

use Moo;
use Class::Usul::Constants;
use Class::Usul::Types      qw( BaseType );

# Private attributes
has '_usul' => is => 'ro', isa => BaseType,
   handles  => [ qw( config localize lock log ) ],
   init_arg => 'builder', required => TRUE, weak_ref => TRUE;

1;

__END__

=pod

=encoding utf8

=head1 Name

App::Doh - An easy way to document a project using Markdown

=head1 Synopsis

   use App::Doh;
   # Brief but working code examples

=head1 Version

This documents version v0.1.$Rev: 22 $ of L<App::Doh>

=head1 Description

=head1 Configuration and Environment

Defines no attributes

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
