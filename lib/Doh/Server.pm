# @(#)Ident: Server.pm 2013-07-20 22:29 pjf ;

package Doh::Server;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 11 $ =~ /\d+/gmx );

use Class::Usul;
use Class::Usul::Constants;
use Class::Usul::File;
use Class::Usul::Functions  qw( app_prefix find_apphome
                                get_cfgfiles is_hashref trim );
use Class::Usul::Types      qw( HashRef Maybe NonEmptySimpleStr
                                Object SimpleStr );
use Doh::Model::Documentation;
use Doh::Model::Help;
use Doh::View::HTML;
use File::Spec::Functions   qw( catfile updir );
use Plack::Builder;
use Scalar::Util            qw( blessed );
use Web::Simple;

# Public attributes
has 'appclass'     => is => 'ro',   isa => Maybe[SimpleStr];

has 'config_class' => is => 'ro',   isa => NonEmptySimpleStr,
   default         => 'Doh::Config';

has 'doc_model'    => is => 'lazy', isa => Object, init_arg => undef;

has 'help_model'   => is => 'lazy', isa => Object, init_arg => undef;

has 'html_view'    => is => 'lazy', isa => Object, init_arg => undef;

has 'usul'         => is => 'lazy', isa => Object, init_arg => undef;

# Construction
around 'to_psgi_app' => sub {
   my ($orig, $self, @args) = @_; my $app = $orig->( $self, @args );

   my $debug  = $ENV{PLACK_ENV} eq 'development' ? TRUE : FALSE;
   my $conf   = $self->usul->config;
   my $logger = $self->usul->log;

   builder {
      enable 'LogErrors', logger => sub {
         my $p = shift; my $lvl = $p->{level}; $logger->$lvl( $p->{message} ) };
      enable 'Deflater',
         content_type =>
            [ qw( text/css text/html text/javascript application/javascript ) ],
         vary_user_agent => TRUE;
      enable 'Static',
         path => qr{ \A / (css | img | js | less) }mx, root => $conf->root;
      enable_if { $debug } 'Debug';
      $app;
   };
};

sub BUILD { # Take the hit at application startup not on first request
   $_[ 0 ]->doc_model; return;
}

# Public methods
sub dispatch_request {
   sub (GET + /help | /help/** + ?*) {
      my $self = shift; my $req = __get_request( @_ );

      return $self->_set_response( $self->help_model->get_stash( $req ) );
   },
   sub (GET + / | /** + ?*) {
      my $self = shift; my $req = __get_request( @_ );

      return $self->_set_response( $self->doc_model->get_stash( $req ) );
   };
}

# Private methods
sub _build_doc_model {
   return Doh::Model::Documentation->new
      ( builder => $_[ 0 ]->usul, type_map => $_[ 0 ]->html_view->type_map );
}

sub _build_help_model {
   return Doh::Model::Help->new( builder => $_[ 0 ]->usul );
}

sub _build_html_view {
   return Doh::View::HTML->new( builder => $_[ 0 ]->usul );
}

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

sub _set_response {
   my ($self, $stash) = @_; my $res = $self->html_view->render( $stash );

   return [ $res->[ 0 ], [ 'Content-Type', 'text/html' ], [ $res->[ 1 ] ] ];
}

# Private functions
sub __get_request {
   my $env    = ( $_[ -1 ] && is_hashref $_[ -1 ] ) ? pop @_ : {};
   my $params = ( $_[ -1 ] && is_hashref $_[ -1 ] ) ? pop @_ : {};
   my $args   = [ split m{ [/] }mx, trim $_[  0 ] || NUL, '/' ];

   return { args => $args, env => $env, params => $params };
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Doh::Server - One-line description of the modules purpose

=head1 Synopsis

   use Doh::Server;
   # Brief but working code examples

=head1 Version

This documents version v0.1.$Rev: 11 $ of L<Doh::Server>

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
