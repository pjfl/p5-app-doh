# @(#)Ident: Server.pm 2013-07-17 18:38 pjf ;

package Doh::Server;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 5 $ =~ /\d+/gmx );

use Class::Usul;
use Class::Usul::Constants;
use Class::Usul::Functions  qw( find_apphome get_cfgfiles );
use Class::Usul::Types      qw( Maybe Object SimpleStr );
use Doh::Model::Documentation;
use Doh::View::HTML;
use File::Spec::Functions   qw( catfile updir );
use Plack::Builder;
use Scalar::Util            qw( blessed );
use Web::Simple;

# Public attributes
has 'appclass'  => is => 'ro',   isa => Maybe[SimpleStr];

has 'html_view' => is => 'lazy', isa => Object, init_arg => undef;

has 'model'     => is => 'lazy', isa => Object, init_arg => undef;

has 'usul'      => is => 'lazy', isa => Object, init_arg => undef;

# Construction
around 'to_psgi_app' => sub {
   my ($orig, $self, @args) = @_; my $app = $orig->( $self, @args );

   my $debug  = $ENV{PLACK_ENV} eq 'development' ? TRUE : FALSE;
   my $conf   = $self->usul->config;
   my $logger = $self->usul->log;

   builder {
      enable 'Deflater',
         content_type =>
            [ qw( text/css text/html text/javascript application/javascript ) ],
         vary_user_agent => TRUE;
      enable 'Static',
         path => qr{ \A / (css | img | js | less) }mx, root => $conf->root;
      enable 'LogErrors', logger => sub {
         my $p = shift; my $lvl = $p->{level}; $logger->$lvl( $p->{message} ) };
      enable_if { $debug } 'Debug';
      $app;
   };
};

# Public methods
sub dispatch_request {
   sub (GET + / | /**) {
      my ($self, @args) = @_;

      my $stash = $self->model->get_stash( @args );
      my $res   = $self->html_view->render( $stash );

      return [ $res->[ 0 ], [ 'Content-Type', 'text/html' ], [ $res->[ 1 ] ] ];
   };
}

# Private methods
sub _build_html_view {
   return Doh::View::HTML->new( builder => $_[ 0 ]->usul );
}

sub _build_model {
   return Doh::Model::Documentation->new( builder => $_[ 0 ]->usul );
}

sub _build_usul {
   my $self   = shift;
   my $myconf = $self->config;
   my $home   = $myconf->{home};
   my $extns  = $myconf->{extensions  } || [ '.json' ];
   my $class  = $myconf->{config_class} || 'Doh::Config';
   my $attr   = { config => {}, config_class => $class };
   my $conf   = $attr->{config};

   $conf->{appclass} = $self->appclass || blessed $self || $self;
   $conf->{home    } = find_apphome( $conf->{appclass}, $home, $extns );
   $conf->{cfgfiles} = get_cfgfiles( $conf->{home}, $conf->{appclass}, $extns );

   my $bootstrap = Class::Usul->new( $attr ); my $bootconf = $bootstrap->config;

   $bootconf->inflate_paths( $bootconf->projects );

   my $port    = $ENV{DOH_SERVER_PORT} || $bootconf->port;
   my $docs    = $bootconf->projects->{ $port } || $bootconf->docs_path;
   my $cfgdirs = [ $conf->{home}, -d $docs ? $docs : () ];

   $conf->{cfgfiles} = get_cfgfiles( $cfgdirs, $conf->{appclass}, $extns );

   return Class::Usul->new( $attr );
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

This documents version v0.1.$Rev: 1 $ of L<Doh::Server>

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
