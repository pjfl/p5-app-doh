package App::Doh::Server;

use namespace::autoclean;

use App::Doh::Util         qw( enhance is_static );
use Class::Usul;
use Class::Usul::Constants qw( NUL TRUE );
use Class::Usul::Functions qw( ensure_class_loaded );
use Class::Usul::Types     qw( HashRef Plinth );
use HTTP::Status           qw( HTTP_FOUND );
use Plack::Builder;
use Web::Simple;

# Private attributes
has '_config_attr' => is => 'ro',   isa => HashRef,
   builder         => sub { {} }, init_arg => 'config';

has '_usul'        => is => 'lazy', isa => Plinth,
   builder         => sub { Class::Usul->new( enhance $_[ 0 ]->_config_attr ) },
   handles         => [ 'config', 'debug', 'dumper', 'l10n', 'lock', 'log' ];

with 'Web::Components::Loader';

# Construction
around 'to_psgi_app' => sub {
   my ($orig, $self, @args) = @_; my $psgi_app = $orig->( $self, @args );

   my $conf = $self->config; my $static = $conf->serve_as_static;

   return builder {
      enable 'ContentLength';
      enable 'FixMissingBodyInRedirect';
      enable 'ConditionalGET';
      mount $conf->mount_point => builder {
         enable 'Deflater',
            content_type => $conf->deflate_types, vary_user_agent => TRUE;
         enable 'Static',
            path => qr{ \A / (?: $static ) }mx, root => $conf->root;
         enable 'Static',
            path => qr{ \A / static }mx, pass_through => TRUE,
            root => $conf->root;
         enable 'Static',
            path => qr{ \A / assets }mx, pass_through => TRUE,
            root => $conf->file_root;
         enable 'Session::Cookie',
            expires     => 7_776_000,
            httponly    => TRUE,
            path        => $conf->mount_point,
            secret      => $conf->secret,
            session_key => $conf->prefix.'_session';
         enable 'LogDispatch', logger => $self->log;
         enable_if { $self->debug } 'Debug';
         $psgi_app;
      };
      mount '/' => builder {
         sub { [ HTTP_FOUND, [ 'Location', $conf->default_route ], [] ] }
      };
   };
};

sub BUILD {
   my $self   = shift;
   my $conf   = $self->config;
   my $server = ucfirst( $ENV{PLACK_ENV} // NUL );
   my $class  = $conf->appclass; ensure_class_loaded $class;
   my $port   = $class->env_var( 'PORT' );
   my $info   = 'v'.$class->VERSION; $port and $info .= " on port ${port}";

   is_static $class or $self->log->info( "${server} Server started ${info}" );
   # Stop tests failing after a restart
   is_static $class or $conf->root_mtime->unlink;
   # Take the hit at application startup not on first request
   $self->models->{docs }->docs_tree;
   $self->models->{posts}->posts;
   is_static $class or $self->log->info( 'Document tree loaded' );
   return;
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::Doh::Server - A Plack web application server

=head1 Synopsis

   #!/usr/bin/env perl

   use App::Doh::Server;

   App::Doh::Server->new->run_if_script;

=head1 Description

Serves HTML pages generated from microformats like Markdown and POD

=head1 Configuration and Environment

Defines no attributes

=head1 Subroutines/Methods

=head2 C<BUILD>

Calls the documentation model at application start time. Means that the
startup time is longer but the response time for the first request is
shorter

Log the server startup event

=head2 C<dispatch_request>

The L<Web::Simple> API method used to dispatch requests

=head2 C<render>

Each of the L</dispatch_request> methods returns a tuple containing
the model name and method to call in addition to the parameters passed
by L<Web::Simple>. A response filter is installed by the C<Root>
controller handles the tuple by calling this method. It in turn calls
the model and then the view. Wraps the model and view calls in a
C<try> / C<catch> block and renders an exception page if those calls
fail. Creates an L<App::Doh::Request> object which it passes into the
model and view methods calls

=head2 C<to_psgi_app>

Sets the application mount point and pushes some middleware into the
L<Plack> stack

=head1 Diagnostics

Exporting C<APP_DOH_DEBUG> and setting it to true causes the development
server to start logging at the debug level

The development server can be started using

   plackup bin/doh-server

Starting the daemon with the C<-D> option will cause it to print debug
information to the log file F<var/logs/daemon.log>

=head1 Dependencies

=over 3

=item L<Class::Usul>

=item L<Plack>

=item L<Web::Components>

=item L<Web::Simple>

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
