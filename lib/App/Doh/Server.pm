# @(#)Ident: Server.pm 2013-11-23 22:05 pjf ;

package App::Doh::Server;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 22 $ =~ /\d+/gmx );

use App::Doh::Model::Documentation;
use App::Doh::Model::Help;
use App::Doh::Request;
use App::Doh::View::HTML;
use Class::Usul;
use Class::Usul::Constants;
use Class::Usul::File;
use Class::Usul::Functions  qw( app_prefix find_apphome get_cfgfiles );
use Class::Usul::Types      qw( BaseType NonEmptySimpleStr Object );
use Plack::Builder;
use Scalar::Util            qw( blessed );
use Web::Simple;

# Public attributes
has 'appclass'     => is => 'ro',   isa => NonEmptySimpleStr,
   default         => 'App::Doh';

has 'config_class' => is => 'ro',   isa => NonEmptySimpleStr,
   default         => 'App::Doh::Config';

has 'doc_model'    => is => 'lazy', isa => Object, init_arg => undef,
   builder         => sub { App::Doh::Model::Documentation->new
      ( builder    => $_[ 0 ]->usul,
        type_map   => $_[ 0 ]->html_view->type_map ) };

has 'help_model'   => is => 'lazy', isa => Object, init_arg => undef,
   builder         => sub { App::Doh::Model::Help->new
      ( builder    => $_[ 0 ]->usul ) };

has 'html_view'    => is => 'lazy', isa => Object, init_arg => undef,
   builder         => sub { App::Doh::View::HTML->new
      ( builder    => $_[ 0 ]->usul ) };

has 'usul'         => is => 'lazy', isa => BaseType, init_arg => undef;

# Construction
around 'to_psgi_app' => sub {
   my ($orig, $self, @args) = @_; my $app = $orig->( $self, @args );

   my $debug  = $ENV{PLACK_ENV} eq 'development' ? TRUE : FALSE;
   my $conf   = $self->usul->config;
   my $point  = $conf->mount_point;
   my $logger = $self->usul->log;

   builder {
      mount "${point}" => builder {
         enable 'LogErrors', logger => sub {
            my $p = shift; my $lvl = $p->{level};
            $logger->$lvl( $p->{message} ) };
         enable 'Deflater',
            content_type    => [ qw( text/css text/html text/javascript
                                     application/javascript ) ],
            vary_user_agent => TRUE;
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
sub _build_usul {
   my $self   = shift;
   my $myconf = $self->config;
   my $extns  = [ keys %{ Class::Usul::File->extensions } ];
   my $attr   = { config => {}, config_class => $self->config_class, };
   my $conf   = $attr->{config};

   $conf->{appclass} = $self->appclass || blessed $self || $self;
   $conf->{name    } = app_prefix   $conf->{appclass};
   $conf->{home    } = find_apphome $conf->{appclass}, $myconf->{home}, $extns;
   $conf->{cfgfiles} = get_cfgfiles $conf->{appclass},   $conf->{home}, $extns;

   my $bootstrap = Class::Usul->new( $attr ); my $bootconf = $bootstrap->config;

   $bootconf->inflate_paths( $bootconf->projects );

   my $port    = $ENV{DOH_SERVER_PORT} || $bootconf->port;
   my $docs    = $bootconf->projects->{ $port } || $bootconf->docs_path;
   my $cfgdirs = [ $conf->{home}, -d $docs ? $docs : () ];

   $conf->{cfgfiles} = get_cfgfiles $conf->{appclass}, $cfgdirs, $extns;

   return Class::Usul->new( $attr );
}

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

App::Doh::Server - One-line description of the modules purpose

=head1 Synopsis

   use App::Doh::Server;
   # Brief but working code examples

=head1 Version

This documents version v0.1.$Rev: 22 $ of L<App::Doh::Server>

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