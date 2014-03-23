package App::Doh::Server;

use namespace::sweep;

use App::Doh::Model::Documentation;
use App::Doh::Model::Help;
use App::Doh::Request;
use App::Doh::View::HTML;
use Class::Usul;
use Class::Usul::Constants;
use Class::Usul::Functions qw( app_prefix find_apphome get_cfgfiles );
use Class::Usul::Types     qw( BaseType NonEmptySimpleStr Object );
use Plack::Builder;
use Web::Simple;

# Public attributes
has 'appclass'     => is => 'ro',   isa => NonEmptySimpleStr,
   default         => 'App::Doh';

has 'config_class' => is => 'ro',   isa => NonEmptySimpleStr,
   default         => 'App::Doh::Config';

# Private attributes
has '_doc_model'   => is => 'lazy', isa => Object,   reader => 'doc_model',
   builder         => sub { App::Doh::Model::Documentation->new
      ( builder    => $_[ 0 ]->usul,
        type_map   => $_[ 0 ]->html_view->type_map ) };

has '_help_model'  => is => 'lazy', isa => Object,   reader => 'help_model',
   builder         => sub { App::Doh::Model::Help->new
      ( builder    => $_[ 0 ]->usul ) };

has '_html_view'   => is => 'lazy', isa => Object,   reader => 'html_view',
   builder         => sub { App::Doh::View::HTML->new
      ( builder    => $_[ 0 ]->usul ) };

has '_usul'        => is => 'lazy', isa => BaseType, reader => 'usul';

# Construction
sub _build__usul {
   my $self   = shift;
   my $myconf = $self->config;
   my $attr   = { config => {}, config_class => $self->config_class, };
   my $conf   = $attr->{config};

   $conf->{appclass} = $self->appclass;
   $conf->{name    } = app_prefix   $conf->{appclass};
   $conf->{home    } = find_apphome $conf->{appclass}, $myconf->{home};
   $conf->{cfgfiles} = get_cfgfiles $conf->{appclass},   $conf->{home};

   my $bootstrap = Class::Usul->new( $attr ); my $bootconf = $bootstrap->config;

   $bootconf->inflate_paths( $bootconf->projects );

   my $port    = $ENV{DOH_SERVER_PORT} || $bootconf->port;
   my $docs    = $bootconf->projects->{ $port } || $bootconf->docs_path;
   my $cfgdirs = [ $conf->{home}, -d $docs ? $docs : () ];

   $conf->{cfgfiles} = get_cfgfiles $conf->{appclass}, $cfgdirs;

   return Class::Usul->new( $attr );
}

around 'to_psgi_app' => sub {
   my ($orig, $self, @args) = @_; my $app = $orig->( $self, @args );

   my $debug  = $ENV{PLACK_ENV} eq 'development' ? TRUE : FALSE;
   my $conf   = $self->usul->config;
   my $point  = $conf->mount_point;
   my $logger = $self->usul->log;

   builder {
      mount "${point}" => builder {
         enable "LogDispatch", logger => $logger;
         enable 'Deflater',
            content_type    => [ qw( text/css text/html text/javascript
                                     application/javascript ) ],
            vary_user_agent => TRUE;
         # TODO: User Plack::Middleware::Static::Minifier
         enable 'Static',
            path => qr{ \A / (css | img | js | less) }mx, root => $conf->root;
         enable_if { $debug } 'Debug';
         $app;
      };
   };
};

sub BUILD { # Take the hit at application startup not on first request
   $_[ 0 ]->doc_model; return;
}

# Public methods
sub dispatch_request {
   sub (GET + /help | /help/** + ?*) {
      return shift->_get_html_response( 'help_model', @_ );
   },
   sub (GET + / | /** + ?*) {
      return shift->_get_html_response( 'doc_model', @_ );
   };
}

# Private methods
sub _get_html_response {
   my ($self, $model, @args) = @_;

   my $req = App::Doh::Request->new( $self->usul, @args );

   return $self->html_view->render( $req, $self->$model->get_stash( $req ) );
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::Doh::Server - An Plack HTML application server

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

=item C<_doc_model>

A lazily evaluated object reference to the documentation model

=item C<_help_model>

A lazily evaluated object reference to the help model

=item C<_html_view>

A lazily evaluated object reference to the HTML view

=item C<_usul>

A lazily evaluated object reference to an instance of L<Class::Usul>

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

None

=head1 Dependencies

=over 3

=item L<Class::Usul>

=item L<Plack::Builder>

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
