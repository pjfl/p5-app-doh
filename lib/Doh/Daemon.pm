# @(#)Ident: Daemon.pm 2013-07-17 20:48 pjf ;

package Doh::Daemon;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 7 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Types      qw( NonZeroPositiveInt );
use Daemon::Control;
use Moo;
use MooX::Options;
use Plack::Runner;
use Scalar::Util            qw( blessed );

extends q(Class::Usul::Programs);
with    q(Class::Usul::TraitFor::UntaintedGetopts);

has '+config_class' => default => 'Doh::Config';

option 'port'    => is => 'ro', isa => NonZeroPositiveInt,
   documentation => 'Port number for the input event listener',
   default       => sub { $_[ 0 ]->config->port }, format => 'i';

around 'run_chain' => sub {
   my ($orig, $self, @args) = @_; @ARGV = @{ $self->extra_argv };

   my $config  = $self->config; my $name = $config->name;

   Daemon::Control->new( {
      name         => blessed $self || $self,
      lsb_start    => '$syslog $remote_fs',
      lsb_stop     => '$syslog',
      lsb_sdesc    => 'Documentation Server',
      lsb_desc     => 'Manages the Documentation Server daemons',
      path         => $config->pathname,

      directory    => $config->appldir,
      program      => sub { shift; $self->daemon( @_ ) },
      program_args => [],

      pid_file     => $config->rundir->catfile( "${name}_".$self->port.'.pid' ),
      stderr_file  => $self->_stdio_file( 'err' ),
      stdout_file  => $self->_stdio_file( 'out' ),

      fork         => 2,
   } )->run;

   return $orig->( $self, @args ); # Never reached
};

sub daemon {
   Plack::Runner->run( $_[ 0 ]->_get_listener_args ); exit OK;
}

sub _get_listener_args {
   my $self   = shift;
   my $config = $self->config;
   my $port   = $ENV{DOH_SERVER_PORT} = $self->port;
   my $args   = {
      '--port'       => $port,
      '--server'     => $config->server,
      '--access-log' => $config->logsdir->catfile( "access_${port}.log" ),
      '--app'        => $config->binsdir->catfile( 'doh-server' ), };

   return %{ $args };
}

sub _stdio_file {
   my ($self, $extn, $name) = @_; $name ||= $self->config->name;

   return $self->file->tempdir->catfile( "${name}.${extn}" );
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Doh::Daemon - One-line description of the modules purpose

=head1 Synopsis

   use Doh::Daemon;
   # Brief but working code examples

=head1 Version

This documents version v0.1.$Rev: 7 $ of L<Doh::Daemon>

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
