package App::Doh::Server;

use namespace::autoclean;

use App::Doh::Functions    qw( env_var is_static );
use Class::Usul;
use Class::Usul::Constants qw( EXCEPTION_CLASS FALSE NUL TRUE );
use Class::Usul::Functions qw( app_prefix ensure_class_loaded
                               find_apphome get_cfgfiles throw );
use Class::Usul::Types     qw( BaseType );
use Plack::Builder;
use Unexpected::Functions  qw( Unspecified );
use Web::Simple;

has 'usul' => is => 'lazy', isa => BaseType, handles => [ 'log' ];

with q(App::Doh::Role::ComponentLoading);

# Construction
around 'to_psgi_app' => sub {
   my ($orig, $self, @args) = @_; my $app = $orig->( $self, @args );

   my $conf   = $self->usul->config;
   my $point  = $conf->mount_point;
   my $static = $conf->serve_as_static;

   return builder {
      mount "${point}" => builder {
         enable "ConditionalGET";
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
            expires     => 7_776_000, httponly => TRUE,
            path        => $point,    secret   => NUL.$conf->secret,
            session_key => 'doh_session';
         enable "LogDispatch", logger => $self->usul->log;
         enable_if { $self->usul->debug } 'Debug';
         $app;
      };
   };
};

sub BUILD {
   my $self   = shift;
   my $server = ucfirst( $ENV{PLACK_ENV} // NUL );
   my $port   = env_var( 'PORT' ) ? ' on port '.env_var( 'PORT' ) : NUL;
   my $class  = $self->usul->config->appclass; ensure_class_loaded $class;
   my $ver    = $class->VERSION;

   is_static or $self->log->info( "${server} Server started v${ver}${port}" );
   # Take the hit at application startup not on first request
   $self->models->{docs }->docs_tree;
   $self->models->{posts}->posts;
   is_static or $self->log->debug( 'Document tree loaded' );
   return;
}

sub _build_usul {
   my $self = shift;
   my $attr = { config => $self->config, debug => env_var( 'DEBUG' ) // FALSE };
   my $conf = $attr->{config};

   $conf->{appclass    } or  throw Unspecified, args => [ 'application class' ];
   $attr->{config_class} //= $conf->{appclass}.'::Config';
   $conf->{name        } //= app_prefix   $conf->{appclass};
   $conf->{home        }   = find_apphome $conf->{appclass}, $conf->{home};
   $conf->{cfgfiles    }   = get_cfgfiles $conf->{appclass}, $conf->{home};

   my $bootstrap = Class::Usul->new( $attr ); my $bootconf = $bootstrap->config;

   $bootconf->inflate_paths( $bootconf->projects );

   my $port    = env_var( 'PORT' ) // $bootconf->port;
   my $docs    = $bootconf->projects->{ $port } // $bootconf->docs_path;
   my $cfgdirs = [ $conf->{home}, -d $docs ? $docs : () ];

   $conf->{cfgfiles} = get_cfgfiles $conf->{appclass}, $cfgdirs;
   $conf->{l10n_attributes}->{domains} = [ $conf->{name} ];
   $conf->{file_root} = $docs;

   return Class::Usul->new( $attr );
}

# Public methods
sub dispatch_request {
   my $f = sub () { my $self = shift; response_filter { $self->render( @_ ) } };

   return $f, map { $_->dispatch_request } @{ $_[ 0 ]->controllers };
}

1;

__END__

=pod

=encoding utf8

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

Exporting C<DOH_DEBUG> and setting it to true causes the development
server to start logging at the debug level

The development server can be started using

   plackup bin/doh-server

Starting the daemon with the C<-D> option will cause it to print debug
information to the log file F<var/logs/daemon.log>

=head1 Dependencies

=over 3

=item L<Class::Usul>

=item L<HTTP::Status>

=item L<Plack>

=item L<Try::Tiny>

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
