package App::Doh::Model::Administration;

use Moo;
use App::Doh::Attributes;
use App::Doh::Functions    qw( set_element_focus );
use Class::Usul::Constants qw( EXCEPTION_CLASS FALSE NUL TRUE );
use Class::Usul::Functions qw( throw );
use HTTP::Status           qw( HTTP_EXPECTATION_FAILED HTTP_UNAUTHORIZED
                               HTTP_UNPROCESSABLE_ENTITY );
use Try::Tiny;
use Unexpected::Functions  qw( Unspecified );

extends q(App::Doh::Model);
with    q(App::Doh::Role::Authorization);
with    q(App::Doh::Role::CommonLinks);
with    q(App::Doh::Role::PageConfiguration);
with    q(App::Doh::Role::Preferences);

sub activate_user_action : Role(admin) {
   my ($self, $req) = @_;

   my $username = $req->body_params->( 'username' );

   $self->users->activate_user( $username );

   my $message  = [ 'User [_1] activated by [_2]', $username, $req->username ];

   return { redirect => { location => $req->uri, message => $message } };
}

sub deactivate_user_action : Role(admin) {
   my ($self, $req) = @_;

   my $username = $req->body_params->( 'username' );

   $self->users->deactivate_user( $username );

   my $message  = [ 'User [_1] deactivated by [_2]', $username, $req->username];

   return { redirect => { location => $req->uri, message => $message } };
}

sub generate_static_action : Role(admin) {
   my ($self, $req) = @_;

   my $cli = $self->config->binsdir->catfile( 'doh-cli' );
   my $cmd = [ "${cli}", 'make_static' ];

   $self->log->debug( $self->ipc->run_cmd( $cmd, { async => TRUE } )->out );

   my $message = [ 'Static page generation started in the background by [_1]',
                   $req->username ];

   return { redirect => { location => $req->uri, message => $message } };
}

sub get_dialog : Role(anon) {
   my ($self, $req) = @_;

   my $params = $req->query_params;
   my $name   = $params->( 'name' );
   my $stash  = $self->get_stash( $req );
   my $page   = $stash->{page} = { meta     => { id => $params->( 'id' ), },
                                   template => "${name}-user", };

   $page->{literal_js} = set_element_focus( "${name}-user", 'username' );
   $name eq 'login' and $page->{username} = $req->session->username;
   return $stash;
}

sub get_form : Role(admin) {
   my ($self, $req) = @_;

   my $id    = $req->args->[ 0 ] // $req->params->{username};
   my $title = $req->loc( 'Administration' );
   my $stash = $self->get_content( $req );
   my $page  = $stash->{page};

   $page->{auth_roles} = $self->config->auth_roles;
   $page->{form_name } = 'administration';
   $page->{name      } = $title;
   $page->{template  } = 'admin';
   $page->{title     } = $title;
   $page->{users     } = $self->users->list_users( $id );
   return $stash;
}

sub create_user_action : Role(anon) {
   my ($self, $req) = @_;

   my $params  = $req->body_params;
   my $args    = { email    => $params->( 'email' ),
                   id       => $params->( 'username' ),
                   password => $params->( 'password' ), };
   my $user    = $self->users->create_user( $args );
   my $message = [ 'User [_1] created', $user->id ];

   return { redirect => { location => $req->base, message => $message } };
}

sub delete_user_action : Role(admin) {
   my ($self, $req) = @_;

   my $username = $req->body_params->( 'username' );

   $self->users->delete_user( $username );

   my $location = $req->uri_for( 'admin' );
   my $message  = [ 'User [_1] deleted by [_2]', $username, $req->username ];

   return { redirect => { location => $location, message => $message } };
}

sub login_action : Role(anon) {
   my ($self, $req) = @_; my $message;

   my $session  = $req->session;
   my $params   = $req->body_params;
   my $username = $params->( 'username' );

   if ($self->_authenticate( $username, $params->( 'password' ) )) {
      $message = [ 'User [_1] logged in', $username ];
      $session->authenticated( TRUE ); $session->username( $username );
   }
   else {
      $message = [ 'User [_1] access denied', $username ];
      $session->authenticated( FALSE );
   }

   return { redirect => { location => $req->base, message => $message } };
}

sub logout_action : Role(any) {
   my ($self, $req) = @_; my ($location, $message);

   if ($req->authenticated) {
      $location = $req->base;
      $message  = [ 'User [_1] logged out', $req->username ];
      $req->session->authenticated( FALSE );
   }
   else { $location = $req->uri; $message = [ 'User not logged in' ] }

   return { redirect => { location => $location, message => $message } };
}

sub navigation {
   return [ { depth => 0,      name => 'Administration',
              type  => 'file', url  => 'admin' } ];
}

sub update_user_action : Role(admin) {
   my ($self, $req) = @_;

   my $username = $req->body_params->( 'username' );
   my $roles    = $req->body_values( 'roles' );

   $self->users->update_user( { id => $username, roles => $roles } );

   my $message  = [ 'User [_1] updated by [_2]', $username, $req->username ];

   return { redirect => { location => $req->uri, message => $message } };
}

# Private methods
sub _authenticate {
   my ($self, $username, $password) = @_; my ($authenticated, $user);

   $username or throw class => Unspecified, args => [ 'user name' ],
                         rv => HTTP_EXPECTATION_FAILED;
   $password or throw class => Unspecified, args => [ 'password' ],
                         rv => HTTP_EXPECTATION_FAILED;

   try   { $user = $self->users->read_user( $username ) }
   catch { throw error => 'User [_1] unknown: [_2]', args => [ $username, $_ ],
                    rv => HTTP_EXPECTATION_FAILED;
   };

   $user->active or throw error => 'User [_1] account inactive',
                           args => [ $username ], rv => HTTP_UNAUTHORIZED;

   try   { $authenticated = $user->authenticate( $password ) }
   catch { throw error => ucfirst "${_}", rv => HTTP_UNPROCESSABLE_ENTITY };

   return $authenticated;
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::Doh::Model::Administration - One-line description of the modules purpose

=head1 Synopsis

   use App::Doh::Model::Administration;
   # Brief but working code examples

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

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-Doh.
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
# vim: expandtab shiftwidth=3: