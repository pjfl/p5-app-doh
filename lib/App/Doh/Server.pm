package App::Doh::Server;

use namespace::sweep;

use App::Doh::Model::Documentation;
use App::Doh::Model::Help;
use App::Doh::Request;
use App::Doh::View::HTML;
use App::Doh::View::XML;
use Class::Usul;
use Class::Usul::Constants;
use Class::Usul::Functions qw( app_prefix exception find_apphome
                               get_cfgfiles throw );
use Class::Usul::Types     qw( BaseType HashRef NonEmptySimpleStr Object );
use HTTP::Status           qw( HTTP_BAD_REQUEST HTTP_FOUND
                               HTTP_INTERNAL_SERVER_ERROR );
use Plack::Builder;
use Try::Tiny;
use Web::Simple;

# Public attributes
has 'appclass'     => is => 'ro', isa => NonEmptySimpleStr,
   default         => 'App::Doh';

has 'config_class' => is => 'ro', isa => NonEmptySimpleStr,
   default         => 'App::Doh::Config';

# Private attributes
has '_models' => is => 'lazy', isa => HashRef[Object], reader => 'models',
   builder    => sub { {
      'docs'  => App::Doh::Model::Documentation->new
         ( builder  => $_[ 0 ]->usul,
           type_map => $_[ 0 ]->views->{html}->type_map ),
      'help'  => App::Doh::Model::Help->new( builder => $_[ 0 ]->usul ),
   } };

has '_views'  => is => 'lazy', isa => HashRef[Object], reader => 'views',
   builder    => sub { {
      'html'  => App::Doh::View::HTML->new( builder => $_[ 0 ]->usul ),
      'xml'   => App::Doh::View::XML->new ( builder => $_[ 0 ]->usul ),
   } };

has '_usul'   => is => 'lazy', isa => BaseType,
   handles    => [ 'log' ], reader => 'usul';

# Construction
sub BUILD { # Take the hit at application startup not on first request
   $_[ 0 ]->models->{docs}->docs_tree; return;
}

sub _build__usul {
   my $self   = shift;
   my $myconf = $self->config;
   my $attr   = { config => {}, config_class => $self->config_class,
                  debug  => $ENV{DOH_DEBUG} // FALSE, };
   my $conf   = $attr->{config};

   $conf->{appclass} = $self->appclass;
   $conf->{name    } = app_prefix   $conf->{appclass};
   $conf->{home    } = find_apphome $conf->{appclass}, $myconf->{home};
   $conf->{cfgfiles} = get_cfgfiles $conf->{appclass},   $conf->{home};

   my $bootstrap = Class::Usul->new( $attr ); my $bootconf = $bootstrap->config;

   $bootconf->inflate_paths( $bootconf->projects );

   my $port    = $ENV{DOH_PORT} // $bootconf->port;
   my $docs    = $bootconf->projects->{ $port } // $bootconf->docs_path;
   my $cfgdirs = [ $conf->{home}, -d $docs ? $docs : () ];

   $conf->{cfgfiles } = get_cfgfiles $conf->{appclass}, $cfgdirs;
   $conf->{file_root} = $docs;

   return Class::Usul->new( $attr );
}

around 'to_psgi_app' => sub {
   my ($orig, $self, @args) = @_; my $app = $orig->( $self, @args );

   my $conf = $self->usul->config; my $point = $conf->mount_point;

   builder {
      mount "${point}" => builder {
         enable 'Deflater',
            content_type    => [ qw( text/css text/html text/javascript
                                     application/javascript ) ],
            vary_user_agent => TRUE;
         enable 'Static',
            path => qr{ \A / (css | img | js | less) }mx,
            root => $conf->root;
         enable 'Static',
            path => qr{ \A / assets }mx, pass_through => TRUE,
            root => $conf->file_root;
         enable 'Session::Cookie',
            httponly => TRUE,          path        => $point,
            secret   => $conf->secret, session_key => 'doh_session';
         enable '+App::Doh::Auth::Htpasswd',
            file_root => $conf->file_root, params => [ qw( auth edit ) ];
         enable "LogDispatch", logger => $self->usul->log;
         enable_if { $self->usul->debug } 'Debug';
         $app;
      };
   };
};

# Public methods
sub dispatch_request {
   sub (POST + /assets + *file~ + ?*) {
      return shift->_execute( qw( html docs upload_file ), @_ );
   },
   sub (GET  + /dialog + ?*) {
      return shift->_execute( qw( xml  docs dialog ), @_ );
   },
   sub (GET  + /pod | /pod/** + ?*) {
      return shift->_execute( qw( html help content_from_pod ), @_ );
   },
   sub (GET  + /search-results + ?*) {
      return shift->_execute( qw( html docs search_document_tree ), @_ );
   },
   sub (POST + / | /** + ?*) {
      return shift->_execute( qw( html docs from_request ), @_ );
   },
   sub (GET  + / | /** + ?*) {
      return shift->_execute( qw( html docs content_from_file ), @_ );
   };
}

# Private methods
sub _execute {
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

sub _redirect {
   my ($self, $req, $stash) = @_;

   my $code     = $stash->{code    } || HTTP_FOUND;
   my $redirect = $stash->{redirect};
   my $message  = $redirect->{message};

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

Defines the following attributes;

=over 3

=item C<appclass>

A non empty simple string the defaults to C<App::Doh>

=item C<config_class>

A non empty simple string the defaults to C<App::Doh::Config>

=back

=head1 Subroutines/Methods

=head2 BUILD

Calls the documentation model at application start time. Means that the
startup time is longer but the response time for the first request is
shorter

=head2 dispatch_request

The L<Web::Simple> API method used to dispatch requests

=head2 to_psgi_app

Sets the application mount point and pushes some middleware into the Plack
stack

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
