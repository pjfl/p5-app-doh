package strictures::defanged;

use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 2 $ =~ /\d+/gmx );

sub import {
   require strictures; no warnings 'redefine';

   $ENV{PERL_STRICTURES_ENABLED}
      or *strictures::import = sub {
         strict->import; warnings->import( NONFATAL => 'all' ) };

   strictures->import;
   return;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

strictures::defanged - Make strictures the same as just use strict warnings

=head1 Synopsis

   use strictures::defanged;

=head1 Version

This documents version v0.1.$Rev: 2 $ of L<strictures::defanged>

=head1 Description

Monkey patch the L<strictures> import method. Make it the same as just

   use strict;
   use warnings NONFATAL => 'all';

This stops new warnings that appear in new versions of Perl5 from breaking
working programs, which is what can happen when warnings are made fatal

L<Strictures|strictures> also has some heuristic involving version control
directories that I don't care for so that gets patched out also

The C<use strictures::defanged> line needs to appear before the
C<use strictures> line. Once the C<strictures::defanged> import method
has run the C<strictures> import method will have been replaced

Using L<strictures::defanged> has the same program wide scope as L<strictures>.
Once you've used it in your program B<every> package that uses L<strictures>
will be using this instead

If you put this in your script wrappers and not your package code then
programs are unaffected by the additional constraints that C<strictures>
imposes but the package code, and the tests, still get the "benefit"

=head1 Configuration and Environment

Setting the environment variable C<PERL_STRICTURES_ENABLED> to true
skips the patching of the L<strictures> import subroutine and turns
this module into a no-op

=head1 Subroutines/Methods

None

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<strictures>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

This module uses monkey patching, which is bad because it is action at a
distance

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=strictures-defanged.
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
# vim: expandtab shiftwidth=3:
