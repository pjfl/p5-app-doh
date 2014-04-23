package App::Doh;

use 5.010001;
use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 53 $ =~ /\d+/gmx );

use Moo;
use Class::Usul::Constants;
use Class::Usul::Types qw( BaseType );

has 'usul'  => is => 'ro', isa => BaseType,
   handles  => [ qw( config localize lock log ) ],
   init_arg => 'builder', required => TRUE;

1;

__END__

=pod

=encoding utf8

=head1 Name

App::Doh - An easy way to document a project using Markdown

=head1 Synopsis

   # Start the server in the background
   bin/doh-daemon start

   # Stop the background server
   bin/doh-daemon stop

   # Options help
   bin/doh-daemon -?

=head1 Version

This documents version v0.1.$Rev: 53 $ of L<App::Doh>

=head1 Description

A simple microformat document server written in Perl utilising L<Plack>
and L<Web::Simple>

=head1 Configuration and Environment

The configuration file attributes are documented in the L<App::Doh::Config>
package

=head1 Subroutines/Methods

None

=head1 Diagnostics

Starting the daemon with the C<-D> option will cause it to print debug
information to the log file F<var/logs/daemon.log>

The development server can be started using

   plackup bin/doh-server

=head1 Dependencies

=over 3

=item L<Class::Usul>

=item L<Moo>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

=head1 Acknowledgements

=over 3

=item Larry Wall

For the Perl programming language

=item Justin Walsh

For https://github.com/justinwalsh/daux.io from which L<App::Doh> was forked

=back

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
