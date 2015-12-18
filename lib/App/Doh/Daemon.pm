package App::Doh::Daemon;

use namespace::autoclean;

use App::Doh; our $VERSION = $App::Doh::VERSION;

use Class::Usul::Constants qw( EXCEPTION_CLASS NUL OK TRUE );
use Class::Usul::Functions qw( class2appdir get_user throw );
use Class::Usul::Types     qw( NonEmptySimpleStr NonZeroPositiveInt Object );
use Daemon::Control;
use English                qw( -no_match_vars );
use File::Spec::Functions  qw( catfile );
use Plack::Runner;
use Scalar::Util           qw( blessed );
use Unexpected::Functions  qw( Unspecified );
use Moo;
use Class::Usul::Options;

extends q(Class::Usul::Programs);

# Override default in base class
has '+config_class' => default => 'App::Doh::Config';

# Public attributes
option 'app'     => is => 'ro', isa => NonEmptySimpleStr, format => 's',
   documentation => 'Name of the PSGI file',
   default       => 'doh-server';

option 'port'    => is => 'ro', isa => NonZeroPositiveInt, format => 'i',
   documentation => 'Port number for the server to listen on',
   builder       => sub { $_[ 0 ]->config->port }, short => 'p';

option 'server'  => is => 'ro', isa => NonEmptySimpleStr, format => 's',
   documentation => 'Name of the Plack engine to use',
   builder       => sub { $_[ 0 ]->config->server }, short => 's';

option 'workers' => is => 'ro', isa => NonZeroPositiveInt, format => 'i',
   documentation => 'Number of workers to start in pre-forking servers',
   builder       => sub { $_[ 0 ]->config->workers }, short => 'w';

# Private methods
my $_get_listener_args = sub {
   my $self = shift;
   my $conf = $self->config;
   my $logs = $conf->logsdir;
   my $args = { '--app'    => $conf->binsdir->catfile( $self->app ),
                '--server' => $self->server, };

   if ($self->server eq 'FCGI') {
      $args->{ '--access-log' } = $logs->catfile( 'access.log' );
      $args->{ '--listen'     } = $conf->tempdir->catfile( 'fastcgi.sock' );
      $args->{ '--nprocs'     } = $self->workers;
   }
   else {
      $conf->appclass->env_var( 'PORT', my $port = $self->port );
      $args->{ '--access-log' } = $logs->catfile( 'access-${port}.log' );
      $args->{ '--port'       } = $port;

      $self->server eq 'Starman' and $args->{ '--workers' } = $self->workers;
   }

   for my $k (keys %{ $self->options }) {
      $args->{ "--${k}" } = $self->options->{ $k };
   }

   return %{ $args };
};

my $_stdio_file = sub {
   my ($self, $extn, $name) = @_; $name ||= $self->config->name;

   return $self->file->tempdir->catfile( "${name}.${extn}" );
};

my $_daemon = sub {
   my $self = shift; $PROGRAM_NAME = $self->app;

   $self->config->appclass->env_var( 'DEBUG', $self->debug );
   $self->server ne 'HTTP::Server::PSGI' and $ENV{PLACK_ENV} = 'production';
   Plack::Runner->run( $self->$_get_listener_args );
   exit OK;
};

# Attribute construction
my $_build_daemon_control = sub {
   my $self = shift; my $conf = $self->config; my $name = $conf->name;

   my $appdir = class2appdir $conf->appclass;
   my $args   = {
      name         => blessed $self || $self,
      lsb_start    => '$syslog $remote_fs',
      lsb_stop     => '$syslog',
      lsb_sdesc    => 'Documentation Server',
      lsb_desc     => 'Manages the Documentation Server daemons',
      path         => $conf->pathname,

      init_config  => catfile( NUL, 'etc', 'default', $appdir ),
      init_code    => '# Init code',

      directory    => $conf->appldir,
      program      => sub { shift; $self->$_daemon( @_ ) },
      program_args => [],

      pid_file     => $conf->rundir->catfile( "${name}_".$self->port.'.pid' ),
      stderr_file  => $self->$_stdio_file( 'err' ),
      stdout_file  => $self->$_stdio_file( 'out' ),

      fork         => 2,
   };

   $conf->user and $args->{user} = $args->{group} = $conf->user;

   return Daemon::Control->new( $args );
};

# Private attributes
has '_daemon_control' => is => 'lazy', isa => Object,
   builder            => $_build_daemon_control;

# Construction
# Construction
around 'BUILDARGS' => sub {
   my ($orig, $self, @args) = @_; my $attr = $orig->( $self, @args );

   my $conf = $attr->{config}; $conf->{name} //= class2appdir $conf->{appclass};

   $conf->{l10n_domains} = [ $conf->{name} ];

   return $attr;
};

around 'run' => sub {
   my ($orig, $self) = @_; my $daemon = $self->_daemon_control;

   $daemon->name     or throw Unspecified, [ 'name'     ];
   $daemon->program  or throw Unspecified, [ 'program'  ];
   $daemon->pid_file or throw Unspecified, [ 'pid file' ];

   $daemon->uid and not $daemon->gid
      and $daemon->gid( get_user( $daemon->uid )->gid );

   $self->quiet( TRUE );

   return $orig->( $self );
};

# Public methods
sub get_init_file : method {
   return $_[ 0 ]->_daemon_control->do_get_init_file;
}

sub restart : method {
   my $self = shift; $self->params->{restart} = [ { expected_rv => 1 } ];

   return $self->_daemon_control->do_restart;
}

sub show_warnings : method {
   $_[ 0 ]->_daemon_control->do_show_warnings; return OK;
}

sub start : method {
   my $self = shift; $self->params->{start} = [ { expected_rv => 1 } ];

   return $self->_daemon_control->do_start;
}

sub status : method {
   my $self = shift; $self->params->{status} = [ { expected_rv => 3 } ];

   return $self->_daemon_control->do_status;
}

sub stop : method {
   my $self = shift; $self->params->{stop} = [ { expected_rv => 1 } ];

   return $self->_daemon_control->do_stop;
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::Doh::Daemon - Background process control for the documentation server

=head1 Synopsis

   use App::Doh::Daemon;

   exit App::Doh::Daemon->new_with_options( appclass => 'App::Doh' )->run;

=head1 Description

Manages the documentation web server process. The command line wrapper for this
class provides a SYSV initialisation script

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<app>

The name of the PSGI file in the F<bin> directory

=item C<config_class>

Defaults to C<App::Doh::Config> the name of the applications configuration
class

=item C<port>

The port number for the server to listen on

=item C<server>

The name of the L<Plack> engine used by the server

=item C<workers>

The number of worker processes to start in pre-forking servers. Defaults to 5

=back

=head1 Subroutines/Methods

Defines the following methods;

=head2 C<BUILDARGS>

Constructor signature processing

=head2 C<get_init_file> - Dump SYSV initialisation script to stdout

Dump the SYSV initialisation script to stdout

=head2 C<restart> - Restart the server

Restart the server

=head2 C<run> - Call the requested method

Validates some L<Daemon::Control> attribute values and then calls the
same method in the parent class which, in turn, calls the requested
method in a try / catch block

=head2 C<show_warnings> - Show server warnings

Show server warnings

=head2 C<start> - Start the server

Start the server

=head2 C<status> - Show the current server status

Show the current server status

=head2 C<stop> - Stop the server

Stop the server

=head1 Diagnostics

None

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
