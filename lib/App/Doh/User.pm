package App::Doh::User;

use namespace::autoclean;

use Moo;
use Class::Usul::Constants     qw( EXCEPTION_CLASS FALSE NUL TRUE );
use Class::Usul::Functions     qw( create_token throw );
use Class::Usul::Types         qw( NonZeroPositiveInt );
use Crypt::Eksblowfish::Bcrypt qw( bcrypt en_base64 );

extends q(File::DataClass::Schema);

has 'load_factor' => is => 'ro', isa => NonZeroPositiveInt, default => 14;

has '+result_source_attributes' => default => sub { {
   users                   => {
      attributes           => [ qw( active email password roles ) ],
      defaults             => { roles => [], },
      resultset_attributes => { result_class => 'App::Doh::User::Result' } },
} };

# Public methods
sub activate_user {
   return $_[ 0 ]->update_user( { id => $_[ 1 ], active => TRUE } );
}

sub create_user {
   my ($self, $args) = @_;

   $args->{active  }   = FALSE;
   $args->{email   } //= NUL;
   $args->{password}   = bcrypt( $args->{password}, $self->_new_salt );
   $args->{roles   } //= [ 'users' ];

   return $self->_resultset->create( $args );
}

sub deactivate_user {
   return $_[ 0 ]->update_user( { id => $_[ 1 ], active => FALSE } );
}

sub delete_user {
   return $_[ 0 ]->_resultset->delete( $_[ 1 ] );
}

sub list_users {
   return $_[ 0 ]->_resultset->list( $_[ 1 ] // NUL );
}

sub read_user {
   return $_[ 0 ]->_resultset->find( $_[ 1 ] );
}

sub update_user {
   return $_[ 0 ]->_resultset->find_and_update( $_[ 1 ] );
}

# Private metods
sub _new_salt {
   my $lf = $_[ 0 ]->load_factor;

   return "\$2a\$${lf}\$"
      .(en_base64( pack( 'H*', substr( create_token, 0, 32 ) ) ) );
}

sub _resultset {
   return $_[ 0 ]->resultset( 'users' );
}

1;

package # Hide from indexer
   App::Doh::User::Result;

use Moo;
use Class::Usul::Constants     qw( FALSE TRUE );
use Crypt::Eksblowfish::Bcrypt qw( bcrypt );

extends q(File::DataClass::Result);

sub authenticate {
   my ($self, $password) = @_;

   my $supplied = bcrypt( $password, $self->password );

   return $supplied eq $self->password ? TRUE : FALSE;
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::Doh::User - One-line description of the modules purpose

=head1 Synopsis

   use App::Doh::User;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=item C<load_factor>

The value passed to C<bcrypt> when creating new hashed passwords

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
