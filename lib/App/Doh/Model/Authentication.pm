package App::Doh::Model::Authentication;

use namespace::autoclean;

use Moo;
use App::Doh::Functions        qw( set_element_focus );
use Class::Usul::Constants     qw( FALSE NUL TRUE );
use Class::Usul::Functions     qw( throw );
use Crypt::Eksblowfish::Bcrypt qw( bcrypt );
use HTTP::Status               qw( HTTP_EXPECTATION_FAILED HTTP_UNAUTHORIZED );
use Unexpected::Functions      qw( Unspecified );

extends q(App::Doh::Model);
with    q(App::Doh::Role::CommonLinks);
with    q(App::Doh::Role::PageConfiguration);
with    q(App::Doh::Role::Preferences);

sub get_dialog {
   my ($self, $req) = @_; my $stash = $self->get_stash( $req );

   $stash->{page} = {
      literal_js => set_element_focus( 'login-user', 'username' ),
      meta       => { id => $req->query_params->( 'id' ), },
      template   => 'login-user',
      username   => $req->session->{username} // NUL, };

   return $stash;
}

sub login_action {
   my ($self, $req) = @_; my $message;

   my $session  = $req->session;
   my $params   = $req->body_params;
   my $username = $params->( 'username' );

   if ($self->_authenticate( $username, $params->( 'password' ) )) {
      $message = [ 'User [_1] logged in', $username ];
      $session->{authenticated} = TRUE; $session->{username} = $username;
   }
   else {
      $message = [ 'User [_1] access denied', $username ];
      $session->{authenticated} = FALSE;
   }

   return { redirect => { location => $req->base, message => $message } };
}

sub logout_action {
   my ($self, $req) = @_; my ($location, $message);

   if ($req->authenticated) {
      $location = $req->base;
      $message  = [ 'User [_1] logged out', $req->username ];
      $req->session->{authenticated} = FALSE;
   }
   else { $location = $req->uri; $message = [ 'User not logged in' ] }

   return { redirect => { location => $location, message => $message } };
}

# Private methods
sub _authenticate {
   my ($self, $username, $password) = @_;

   $username or throw class => Unspecified, args => [ 'user name' ],
                         rv => HTTP_EXPECTATION_FAILED;
   $password or throw class => Unspecified, args => [ 'password' ],
                         rv => HTTP_EXPECTATION_FAILED;

   my $tuple = $self->config->{users}->{ $username }
      or throw error => 'User [_1] unknown', args => [ $username ],
                  rv => HTTP_EXPECTATION_FAILED;

   $tuple->[ 0 ] or throw error => 'User [_1] account inactive',
                           args => [ $username ], rv => HTTP_UNAUTHORIZED;

   bcrypt( $password, $tuple->[ 1 ] ) eq $tuple->[ 1 ] and return TRUE;

   return FALSE;
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::Doh::Model::User - One-line description of the modules purpose

=head1 Synopsis

   use App::Doh::Model::User;
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
