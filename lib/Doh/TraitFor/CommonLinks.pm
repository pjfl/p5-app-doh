# @(#)Ident: CommonLinks.pm 2013-08-19 12:28 pjf ;

package Doh::TraitFor::CommonLinks;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 18 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Functions  qw( throw );
use Moo::Role;

requires qw( config );

around 'get_stash' => sub {
   my ($orig, $self, $req) = @_; my $stash = $orig->( $self, $req );

   $stash->{links} = $self->_get_links( $req );
   return $stash;
};

sub _get_links {
   my ($self, $req) = @_; my $conf = $self->config; my $links = {};

   $links->{css      } = $self->uri_for( $req, $conf->css           );
   $links->{generator} = $self->uri_for( $req, $conf->generator_url );
   $links->{images   } = $self->uri_for( $req, $conf->images        );
   $links->{js       } = $self->uri_for( $req, $conf->js            );
   return $links;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Doh::TraitFor::CommonLinks - One-line description of the modules purpose

=head1 Synopsis

   use Doh::TraitFor::CommonLinks;
   # Brief but working code examples

=head1 Version

This documents version v0.1.$Rev: 18 $ of L<Doh::TraitFor::CommonLinks>

=head1 Description

=head1 Configuration and Environment

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
