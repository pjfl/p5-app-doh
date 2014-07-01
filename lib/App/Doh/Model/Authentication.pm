package App::Doh::Model::Authentication;

use Moo;
use App::Doh::Attributes;
use App::Doh::Functions    qw( set_element_focus );
use Class::Usul::Constants qw( NUL );
use Class::Usul::Functions qw( throw );

extends q(App::Doh::Model);
with    q(App::Doh::Role::Authorization);
with    q(App::Doh::Role::CommonLinks);
with    q(App::Doh::Role::PageConfiguration);
with    q(App::Doh::Role::Preferences);

sub get_dialog : Role(anon) {
   my ($self, $req) = @_;

   my $params = $req->query_params;
   my $stash  = $self->get_stash( $req );
   my $page   = $stash->{page} = { meta     => { id => $params->( 'id' ), },
                                   template => 'login-user', };

   $page->{literal_js} = set_element_focus( 'login-user', 'username' );
   $page->{username  } = $req->session->{username} // NUL;

   return $stash;
}

sub login_action : Role(anon) {
   my ($self, $req) = @_;

   my $params   = $req->body_params;
   my $username = $params->( 'username' );

   $req->session->{username} = $username;

   my $message  = [ 'User [_1] logged in', $username ];

   return { redirect => { location => $req->base, message => $message } };
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
