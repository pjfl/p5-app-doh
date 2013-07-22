# @(#)Ident: Daemon.pm 2013-07-21 18:57 pjf ;

package Doh::Daemon;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 12 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Functions  qw( throw );
use Class::Usul::Types      qw( NonEmptySimpleStr NonZeroPositiveInt Object );
use Daemon::Control;
use English                 qw( -no_match_vars );
use Moo;
use MooX::Options;
use Plack::Runner;
use Scalar::Util            qw( blessed );

extends q(Class::Usul::Programs);
with    q(Class::Usul::TraitFor::UntaintedGetopts);

# Override default in base class
has '+config_class' => default => 'Doh::Config';

# Public attributes
option 'app'     => is => 'ro', isa => NonEmptySimpleStr,
   documentation => 'Name of the PSGI file',
   default       => 'doh-server', format => 's';

option 'port'    => is => 'ro', isa => NonZeroPositiveInt,
   documentation => 'Port number for the server to listen on',
   default       => sub { $_[ 0 ]->config->port }, format => 'i', short => 'p';

option 'server'  => is => 'ro', isa => NonEmptySimpleStr,
   documentation => 'Name of the Plack engine to use',
   default       => sub { $_[ 0 ]->config->server }, format => 's',
   short         => 's';

# Private attributes
has '_daemon_control' => is => 'lazy', isa => Object;

# Construction
around 'run' => sub {
   my ($orig, $self) = @_; my $daemon = $self->_daemon_control;

   $daemon->name     or throw 'Name must be defined';
   $daemon->program  or throw 'Program must be defined';
   $daemon->pid_file or throw 'Pid file must be defined';

   $daemon->uid and not $daemon->gid
      and $daemon->gid( (getpwuid( $daemon->uid ))[ 3 ] );

   $self->quiet( TRUE );

   return $orig->( $self );
};

# Public methods
sub get_init_file : method {
   $_[ 0 ]->_daemon_control->do_get_init_file; return OK;
}

sub restart : method {
   $_[ 0 ]->_daemon_control->do_restart; return OK;
}

sub show_warnings : method {
   $_[ 0 ]->_daemon_control->do_show_warnings; return OK;
}

sub start : method {
   $_[ 0 ]->_daemon_control->do_start; return OK;
}

sub status : method {
   $_[ 0 ]->_daemon_control->do_status; return OK;
}

sub stop : method {
   $_[ 0 ]->_daemon_control->do_stop; return OK;
}

# Private methods
sub _build__daemon_control {
   my $self = shift; my $config = $self->config; my $name = $config->name;

   return Daemon::Control->new( {
      name         => blessed $self || $self,
      lsb_start    => '$syslog $remote_fs',
      lsb_stop     => '$syslog',
      lsb_sdesc    => 'Documentation Server',
      lsb_desc     => 'Manages the Documentation Server daemons',
      path         => $config->pathname,

      directory    => $config->appldir,
      program      => sub { shift; $self->_daemon( @_ ) },
      program_args => [],

      pid_file     => $config->rundir->catfile( "${name}_".$self->port.'.pid' ),
      stderr_file  => $self->_stdio_file( 'err' ),
      stdout_file  => $self->_stdio_file( 'out' ),

      fork         => 2,
   } );
}

sub _daemon {
   my $self = shift; $PROGRAM_NAME = $self->app;

   $self->server ne 'HTTP::Server::PSGI' and $ENV{PLACK_ENV} = 'production';

   Plack::Runner->run( $self->_get_listener_args );
   exit OK;
}

sub _get_listener_args {
   my $self   = shift;
   my $config = $self->config;
   my $port   = $ENV{DOH_SERVER_PORT} = $self->port;
   my $args   = {
      '--port'       => $port,
      '--server'     => $self->server,
      '--access-log' => $config->logsdir->catfile( "access_${port}.log" ),
      '--app'        => $config->binsdir->catfile( $self->app ), };

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

This documents version v0.1.$Rev: 12 $ of L<Doh::Daemon>

=head1 Description

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<app>

The name of the PSGI file in the F<bin> directory

=item C<port>

The port number for the server to listen on

=item C<server>

The name of the L<Plack> engine used by the server

=back

=head1 Subroutines/Methods

Defines the following methods

=head2 get_init_file - Dump the SYSV init script to stdout

Dump the SYSV init script to stdout

=head2 restart - Restart the server

Restart the server

=head2 show_warnings - Show server warnings

Show server warnings

=head2 start - Start the server

Start the server

=head2 status - Show the current server status

Show the current server status

=head2 stop - Stop the server

Stop the server

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Usul>

=item L<Daemon::Control>

=item L<Plack>

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
