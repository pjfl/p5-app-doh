# @(#)Ident: Preferences.pm 2013-08-06 22:36 pjf ;

package Doh::TraitFor::Preferences;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 15 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Functions  qw( base64_decode_ns );
use Storable                qw( thaw );
use Moo::Role;

requires qw( config );

sub preferences {
   my ($self, $req) = @_; my $conf = $self->config; my $r = {};

   my $cookie = $req->{cookie}->{ $conf->name.'_prefs' };
   my $frozen = base64_decode_ns( $cookie ? $cookie->value : FALSE );
   my $prefs  = $frozen ? thaw $frozen : {};

   for my $k (@{ $conf->preferences }) {
      $r->{ $k } = $req->{params}->{ $k } // $prefs->{ $k } // $conf->$k();
   }

   return $r;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Doh::TraitFor::Preferences - One-line description of the modules purpose

=head1 Synopsis

   use Doh::TraitFor::Preferences;
   # Brief but working code examples

=head1 Version

This documents version v0.1.$Rev: 15 $ of L<Doh::TraitFor::Preferences>

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
http://rt.cpan.org/NoAuth/Bugs.html?Dist=Doh.
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
