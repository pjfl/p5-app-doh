package App::Doh::Server;

use namespace::autoclean;

use App::Doh::Controller::Root;
use App::Doh::Model::Authentication;
use App::Doh::Model::Documentation;
use App::Doh::Model::Help;
use App::Doh::Model::Posts;
use App::Doh::Request;
use App::Doh::View::HTML;
use App::Doh::View::XML;
use Class::Usul;
use Class::Usul::Constants qw( FALSE NUL TRUE );
use Class::Usul::Functions qw( app_prefix exception find_apphome
                               get_cfgfiles throw );
use Class::Usul::Types     qw( ArrayRef BaseType HashRef
                               NonEmptySimpleStr Object );
use HTTP::Status           qw( HTTP_BAD_REQUEST HTTP_FOUND
                               HTTP_INTERNAL_SERVER_ERROR );
use Plack::Builder;
use Try::Tiny;
use Web::Simple;

# Private attributes
has '_controllers' => is => 'lazy', isa => ArrayRef[Object], builder => sub {
   [  App::Doh::Controller::Root->new, ] }, reader => 'controllers';

has '_models' => is => 'lazy', isa => HashRef[Object], builder => sub { {
   'auth'     => App::Doh::Model::Authentication->new
      ( builder  => $_[ 0 ]->usul ),
   'docs'     => App::Doh::Model::Documentation->new
      ( builder  => $_[ 0 ]->usul,
        type_map => $_[ 0 ]->views->{html}->type_map ),
   'help'     => App::Doh::Model::Help->new( builder => $_[ 0 ]->usul ),
   'posts'    => App::Doh::Model::Posts->new
      ( builder  => $_[ 0 ]->usul,
        type_map => $_[ 0 ]->views->{html}->type_map ), } },
   reader     => 'models';

has '_views'  => is => 'lazy', isa => HashRef[Object], builder => sub { {
   'html'     => App::Doh::View::HTML->new( builder => $_[ 0 ]->usul ),
   'xml'      => App::Doh::View::XML->new ( builder => $_[ 0 ]->usul ), } },
   reader     => 'views';

has '_usul'   => is => 'lazy', isa => BaseType, handles => [ 'log' ],
   reader     => 'usul';

# Construction
around 'to_psgi_app' => sub {
   my ($orig, $self, @args) = @_; my $app = $orig->( $self, @args );

   my $conf  = $self->usul->config; my $point = $conf->mount_point;

   my @types = qw( text/css text/html text/javascript application/javascript );

   builder {
      mount "${point}" => builder {
         enable 'Deflater',
            content_type  => [ @types ], vary_user_agent => TRUE;
         enable 'Static',
            path => qr{ \A / (css | img | js | less) }mx, root => $conf->root;
         enable 'Static',
            path => qr{ \A / static }mx, pass_through => TRUE,
            root => $conf->root;
         enable 'Static',
            path => qr{ \A / assets }mx, pass_through => TRUE,
            root => $conf->file_root;
         enable 'Session::Cookie',
            httponly => TRUE,          path        => $point,
            secret   => $conf->secret, session_key => 'doh_session';
         enable "LogDispatch", logger => $self->usul->log;
         enable_if { $self->usul->debug } 'Debug';
         $app;
      };
   };
};

sub BUILD {
   my $self   = shift;
   my $ver    = $App::Doh::VERSION;
   my $server = ucfirst( $ENV{PLACK_ENV} // NUL );
   my $port   = $ENV{DOH_PORT} ? ' on port '.$ENV{DOH_PORT} : NUL;
   my $static = !!$ENV{DOH_MAKE_STATIC};

   $static or $self->log->info( "${server} Server started v${ver}${port}" );
   # Take the hit at application startup not on first request
   $self->models->{docs }->docs_tree;
   $self->models->{posts}->posts;
   $static or $self->log->debug( 'Document tree loaded' );
   return;
}

sub _build__usul {
   my $self = shift;
   my $attr = { config       => $self->config,
                config_class => 'App::Doh::Config',
                debug        => $ENV{DOH_DEBUG} // FALSE, };
   my $conf = $attr->{config};

   $conf->{appclass} //= 'App::Doh';
   $conf->{name    } //= app_prefix   $conf->{appclass};
   $conf->{home    }   = find_apphome $conf->{appclass}, $conf->{home};
   $conf->{cfgfiles}   = get_cfgfiles $conf->{appclass}, $conf->{home};

   my $bootstrap = Class::Usul->new( $attr ); my $bootconf = $bootstrap->config;

   $bootconf->inflate_paths( $bootconf->projects );

   my $port    = $ENV{DOH_PORT} // $bootconf->port;
   my $docs    = $bootconf->projects->{ $port } // $bootconf->docs_path;
   my $cfgdirs = [ $conf->{home}, -d $docs ? $docs : () ];

   $conf->{cfgfiles} = get_cfgfiles $conf->{appclass}, $cfgdirs;
   $conf->{l10n_attributes}->{domains} = [ $conf->{name} ];
   $conf->{file_root} = $docs;

   return Class::Usul->new( $attr );
}

# Public methods
sub dispatch_request {
   return map { $_->dispatch_request } @{ $_[ 0 ]->controllers };
}

sub execute {
   my ($self, $view, $model, $method, @args) = @_; my ($req, $res);

   try   { $req = App::Doh::Request->new( $self->usul, @args ) }
   catch { $res = __internal_server_error( $_ ) };

   $res and return $res;

   try {
      $method eq 'from_request' and $method = $req->tunnel_method.'_action';

      my $stash = $self->models->{ $model }->execute( $method, $req );

      exists $stash->{redirect} and $res = $self->_redirect( $req, $stash );

      $res or $res = $self->views->{ $view }->serialize( $req, $stash )
           or throw error => 'View [_1] returned false', args => [ $view ];
   }
   catch { $res = $self->_render_exception( $view, $model, $req, $_ ) };

   return $res;
}

# Private methods
sub _redirect {
   my ($self, $req, $stash) = @_; my $code = $stash->{code} || HTTP_FOUND;

   my $redirect = $stash->{redirect}; my $message = $redirect->{message};

   $message and $req->session->{status_message} = $req->loc( @{ $message } )
            and $self->log->info( $req->loc_default( @{ $message } ) );

   return [ $code, [ 'Location', $redirect->{location} ], [] ];
}

sub _render_exception {
   my ($self, $view, $model, $req, $e) = @_; my $res;

   my $msg = "${e}"; chomp $msg; $self->log->error( $msg );

   $e->can( 'rv' ) or $e = exception error => $msg, rv => HTTP_BAD_REQUEST;

   try {
      my $stash = $self->models->{ $model }->exception_handler( $req, $e );

      $res = $self->views->{ $view }->serialize( $req, $stash )
          or throw error => 'View [_1] returned false', args => [ $view ];
   }
   catch { $res = __internal_server_error( $e, $_ ) };

   return $res;
}

# Private functions
sub __internal_server_error {
   my ($e, $secondary_error) = @_; my $message = "${e}\r\n";

   $secondary_error and $message .= "Secondary error: ${secondary_error}";

   return [ HTTP_INTERNAL_SERVER_ERROR, __plain_header(), [ $message ] ];
}

sub __plain_header {
   return [ 'Content-Type', 'text/plain' ];
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

=head2 C<execute>

   $plack_response = $self->execute( $view, $model, $method, @args );

Each of the L</dispatch_request> methods calls this which in turn
calls the model and then the view. Wraps the model and view calls in a
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
