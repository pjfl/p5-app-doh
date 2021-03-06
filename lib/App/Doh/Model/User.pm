package App::Doh::Model::User;

use namespace::autoclean;

use Class::Usul::Constants     qw( EXCEPTION_CLASS FALSE NUL TRUE );
use Class::Usul::Functions     qw( create_token is_hashref );
use Class::Usul::Types         qw( NonEmptySimpleStr
                                   NonZeroPositiveInt Object );
use Crypt::Eksblowfish::Bcrypt qw( bcrypt en_base64 );
use Data::Validation;
use Moo;

extends q(File::DataClass::Schema);

has 'load_factor'  => is => 'ro', isa => NonZeroPositiveInt, default => 14;

has 'min_pass_len' => is => 'ro', isa => NonZeroPositiveInt, default => 8;

has 'moniker'      => is => 'ro', isa => NonEmptySimpleStr,  default => 'user';

has '+result_source_attributes' => default => sub { {
   users                   => {
      attributes           => [ qw( active binding email password roles ) ],
      defaults             => {
         active            => FALSE,
         binding           => 'default',
         roles             => [ 'user' ], },
      resultset_attributes => { result_class => 'App::Doh::User' } },
} };

has 'validator'    => is => 'lazy', isa => Object, builder => sub {
   Data::Validation->new( {
      constraints  => { password => { min_length => $_[ 0 ]->min_pass_len } },
      fields       => {
         binding   => { validate => 'isValidIdentifier' },
         email     => { validate => 'isMandatory isValidEmail' },
         password  => { validate => 'isMandatory isValidPassword' }, }, } ) };

# Private methods
my $_encrypt_password = sub {
   my ($self, $password) = @_; my $lf = $self->load_factor;

   my $salt = "\$2a\$${lf}\$"
              .(en_base64( pack( 'H*', substr( create_token, 0, 32 ) ) ) );

   return bcrypt( $password, $salt );
};

my $_resultset = sub {
   return $_[ 0 ]->resultset( 'users' );
};

# Construction
around 'BUILDARGS' => sub {
   my ($orig, $self, @args) = @_;

   my $attr = (is_hashref $args[ 0 ]) ? $args[ 0 ] : { @args };
   my $app  = delete $attr->{application}; $app and $attr->{builder} = $app;

   return $orig->( $self, $attr );
};

# Public methods
sub create {
   my ($self, $args) = @_;

   $args = $self->validator->check_form( NUL, $args );
   $args->{password} = $self->$_encrypt_password( $args->{password} );

   return $self->$_resultset->create( $args );
}

sub delete {
   return $_[ 0 ]->$_resultset->delete( $_[ 1 ] );
}

sub find {
   return $_[ 0 ]->$_resultset->find( $_[ 1 ] );
}

sub list {
   return $_[ 0 ]->$_resultset->list( $_[ 1 ] // NUL );
}

sub update {
   my ($self, $args) = @_;

   $args = $self->validator->check_form( NUL, $args );
   $args->{password} and $args->{password} !~ m{ \A \$ 2a }mx
      and $args->{password} = $self->$_encrypt_password( $args->{password} );

   return $self->$_resultset->find_and_update( $args );
}

package # Hide from indexer
   App::Doh::User;

use namespace::autoclean;

use Class::Usul::Constants     qw( FALSE TRUE );
use Crypt::Eksblowfish::Bcrypt qw( bcrypt );
use Moo;

extends q(File::DataClass::Result);

sub authenticate {
   my ($self, $plain) = @_;

   my $encrypted = bcrypt( $plain, $self->password );

   return $encrypted eq $self->password ? TRUE : FALSE;
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::Doh::User - Schema for the user model

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
