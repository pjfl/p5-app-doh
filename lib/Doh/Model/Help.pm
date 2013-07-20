# @(#)Ident: Help.pm 2013-07-20 03:07 pjf ;

package Doh::Model::Help;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 9 $ =~ /\d+/gmx );

use Moo;

extends q(Doh);

sub get_stash {
   my ($self, $req) = @_; my $conf = $self->config;

   my $src = $conf->appldir->catfile( qw( lib Doh.pm ) );

   return {
      config   => $conf,
      nav      => [],
      page     => { content => { src   => $src->pathname,
                                 title => $conf->{appclass}.' Help',
                                 url   => 'https://metacpan.org/module/%s', },
                    format  => 'pod', },
      template => 'documentation.tt',
      theme    => $req->{params}->{ 'theme' } || $conf->theme,
   };
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Doh::Model::Help - One-line description of the modules purpose

=head1 Synopsis

   use Doh::Model::Help;
   # Brief but working code examples

=head1 Version

This documents version v0.1.$Rev: 9 $ of L<Doh::Model::Help>

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
