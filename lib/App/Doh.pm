package App::Doh;

use 5.010001;
use strictures;
use version; our $VERSION = qv( sprintf '0.15.%d', q$Rev: 3 $ =~ /\d+/gmx );

use Class::Usul::Functions  qw( env_prefix );

sub env_var {
   my ($class, $var, $v) = @_; my $k = (env_prefix __PACKAGE__)."_${var}";

   return defined $v ? $ENV{ $k } = $v : $ENV{ $k };
}

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

This documents version v0.15.$Rev: 3 $ of L<App::Doh>

=head1 Description

A simple microformat document server written in Perl utilising L<Plack>
and L<Web::Simple>

=head1 Configuration and Environment

The configuration file options are documented in the F<App::Doh::Config>
package

The command line methods are documented in F<App::Doh::CLI>

The production server options are detailed in F<App::Doh::Daemon>

F<App::Doh::Server> is the L<Web::Simple> based application server

The request object F<Web::ComposableRequest> represents all that is now about
the current request

=head1 Subroutines/Methods

=head2 C<env_var>

   $value = App::Doh->env_var( 'name', 'value' );

Class method which is an accessor / mutator for the environment variables
used by this application. Providing a value is optional always returns the
current value

=head1 Diagnostics

Exporting C<APP_DOH_DEBUG> and setting it to true causes the development
server to start logging at the debug level to F<var/logs/app_doh.log>

Starting the daemon with the C<-D> option will cause it to log debug
information to the file F<var/logs/daemon.log> and the application will
also start logging at the debug level

The production server logs requests to the file F<var/logs/access_8085.log>

=head1 Dependencies

=over 3

=item L<Class::Usul>

=item L<Web::Simple>

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
