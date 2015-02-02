package App::Doh;

use 5.010001;
use version; our $VERSION = qv( sprintf '0.9.%d', q$Rev: 4 $ =~ /\d+/gmx );

1;

__END__

=pod

=encoding utf-8

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

This documents version v0.9.$Rev: 4 $ of L<App::Doh>

=head1 Description

A simple microformat document server written in Perl utilising L<Plack>
and L<Web::Simple>

=head1 Configuration and Environment

The configuration file options are documented in the F<App::Doh::Config>
package

The command line methods are documented in F<App::Doh::CLI>

The production server options are detailed in F<App::Doh::Daemon>

The request object F<App::Doh::Request> represents all that is now about the
current request

F<App::Doh::Server> is the L<Web::Simple> based application server

Defines these attributes;

=over 3

=item C<moniker>

The abbreviated component name

=item C<usul>

An instance of L<Class::Usul>

=back

=head1 Subroutines/Methods

None

=head1 Diagnostics

Exporting C<DOH_DEBUG> and setting it to true causes the development
server to start logging at the debug level to F<var/logs/app_doh.log>

Starting the daemon with the C<-D> option will cause it to log debug
information to the file F<var/logs/daemon.log> and the application will
also start logging at the debug level

The production server logs requests to the file F<var/logs/access_8085.log>

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

Copyright (c) 2015 Peter Flanigan. All rights reserved

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
