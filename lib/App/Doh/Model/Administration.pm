package App::Doh::Model::Administration;

use App::Doh::Attributes;  # Will do cleaning
use App::Doh::Util         qw( set_element_focus );
use Class::Usul::Constants qw( EXCEPTION_CLASS FALSE NUL TRUE );
use Class::Usul::Functions qw( throw );
use Class::Usul::Types     qw( Object );
use HTTP::Status           qw( HTTP_EXPECTATION_FAILED HTTP_UNAUTHORIZED
                               HTTP_UNPROCESSABLE_ENTITY );
use Try::Tiny;
use Unexpected::Functions  qw( Unspecified );
use Moo;

extends q(App::Doh::Model);
with    q(App::Doh::Role::PageConfiguration);
with    q(App::Doh::Role::Authorization);

has '+moniker' => default => 'admin';

# Private methods
my $_authenticate = sub {
   my ($self, $username, $password) = @_; my $authenticated;

   $username or throw Unspecified, [ 'user name' ],
                      rv => HTTP_EXPECTATION_FAILED;
   $password or throw Unspecified, [ 'password' ],
                      rv => HTTP_EXPECTATION_FAILED;

   my $user = $self->users->find( $username )
      or throw 'User [_1] unknown', [ $username ],
               rv => HTTP_EXPECTATION_FAILED;

   $user->active or throw 'User [_1] account inactive', [ $username ],
                          rv => HTTP_UNAUTHORIZED;

   try   { $authenticated = $user->authenticate( $password ) }
   catch { throw ucfirst "${_}", rv => HTTP_UNPROCESSABLE_ENTITY };

   return $authenticated;
};

# Public methods
sub create_user_action : Role(anon) {
   my ($self, $req) = @_;

   my $params  = $req->body_params;
   my $args    = { id       => $params->( 'username' ),
                   email    => $params->( 'email',    { raw => TRUE } ),
                   password => $params->( 'password', { raw => TRUE } ), };
   my $user    = $self->users->create( $args );
   my $message = [ 'User [_1] created', $user->id ];

   return { redirect => { location => $req->base, message => $message } };
}

sub delete_user_action : Role(admin) {
   my ($self, $req) = @_;

   my $username = $req->body_params->( 'username' );

   $username eq $req->username
      and throw 'Cannot self terminate', rv => HTTP_UNPROCESSABLE_ENTITY;
   $self->users->delete( $username );

   my $location = $req->uri_for( 'admin' );
   my $message  = [ 'User [_1] deleted by [_2]', $username, $req->username ];

   return { redirect => { location => $location, message => $message } };
}

sub generate_static_action : Role(admin) {
   my ($self, $req) = @_;

   # Need to use system to avoid defunct process
   my $opts = { async => TRUE, err => 'out', use_system => TRUE, };
   my $cli  = $self->config->binsdir->catfile( 'doh-cli' );
   my $cmd  = [ "${cli}", 'make_static' ];

   $self->log->debug( $self->run_cmd( $cmd, $opts )->out );

   my $message = [ 'Static page generation started in the background by [_1]',
                   $req->username ];

   return { redirect => { location => $req->uri, message => $message } };
}

sub get_dialog : Role(anon) {
   my ($self, $req) = @_;

   my $params  =  $req->query_params;
   my $name    =  $params->( 'name' );
   my $stash   =  $self->initialise_stash( $req );
   my $page    =  $stash->{page} = $self->load_page( $req, {
      layout   => "${name}-user",
      meta     => { id => $params->( 'id' ), }, } );

   if ($name eq 'profile') {
      my $user = $self->users->find( $page->{username} );

      $page->{binding    } = $user->binding;
      $page->{email      } = $user->email;
      $page->{keybindings} = [ qw( default emacs sublime vim ) ];
      $page->{literal_js } = set_element_focus "${name}-user", 'email';
   }
   else { $page->{literal_js} = set_element_focus "${name}-user", 'username' }

   $stash->{view} = 'json';
   return $stash;
}

sub get_form : Role(admin) {
   my ($self, $req) = @_;

   my $name  = $req->loc( 'Administration' );
   my $id    = $req->uri_params->( 0, { optional => TRUE } )
            // $req->query_params->( 'username', { optional => TRUE } );
   my $page  = { auth_roles => $self->config->auth_roles,
                 form_name  => 'administration',
                 name       => $name,
                 template   => [ 'admin', 'admin' ],
                 title      => ucfirst $name,
                 users      => $self->users->list( $id ), };

   return $self->get_content( $req, $page );
}

sub login_action : Role(anon) {
   my ($self, $req) = @_; my $message;

   my $session  = $req->session;
   my $params   = $req->body_params;
   my $username = $params->( 'username' );
   my $password = $params->( 'password', { raw => TRUE } );

   if ($self->$_authenticate( $username, $password )) {
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
   return [ {
      depth => 0, title => 'Administration', type => 'file', url => 'admin' } ];
}

sub update_profile_action : Role(any) {
   my ($self, $req) = @_;

   my $id      = $req->username;
   my $params  = $req->body_params;
   my $binding = $params->( 'binding' );
   my $email   = $params->( 'email',    { raw => TRUE } );
   my $pass    = $params->( 'password', { raw => TRUE } );
   my $again   = $params->( 'again',    { raw => TRUE } );
   my $user    = $self->users->find( $id );
   my $args    = { id => $id };

   $binding ne $user->binding and $args->{binding} = $binding;
   $email and $email ne $user->email and $args->{email} = $email;

   if ($pass or $again) {
      $pass eq $again or throw 'User [_1] passwords do not match', [ $id ],
                               rv => HTTP_EXPECTATION_FAILED;
      $args->{password} = $pass;
   }

   $self->users->update( $args );

   my $message = [ 'User [_1] profile updated', $id ];

   return { redirect => { location => $req->base, message => $message } };
}

sub update_user_action : Role(admin) {
   my ($self, $req) = @_;

   my $params = $req->body_params;
   my $id     = $params->( 'username' );
   my $active = $params->( 'active', { optional => TRUE } ) // FALSE;
   my $roles  = $params->( 'roles',  { multiple => TRUE } );
   my $user   = $self->users->find( $id );
   my $args   = { id => $id, roles => $roles };

   $active != $user->active and $args->{active} = $active;
   $self->users->update( $args );

   my $message = [ 'User [_1] updated by [_2]', $id, $req->username ];

   return { redirect => { location => $req->uri, message => $message } };
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
# vim: expandtab shiftwidth=3:
