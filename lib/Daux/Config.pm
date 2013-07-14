# @(#)Ident: Config.pm 2013-07-14 00:39 pjf ;

package Daux::Config;


use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 2 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Functions  qw( throw );
use Class::Usul::Types      qw( ArrayRef HashRef NonEmptySimpleStr SimpleStr );
use Moo;

extends q(Class::Usul::Config);

has 'colours'          => is => 'ro', isa => ArrayRef[HashRef],
   default             => sub { [] };

has 'float'            => is => 'ro', isa => SimpleStr,
   coerce              => sub { $_ ? 'float-view' : q() }, default => TRUE;

has 'font'             => is => 'ro', isa => SimpleStr,
   default             => sub {
      'http://fonts.googleapis.com/css?family=Roboto+Slab:400,700,300,100' };

has 'generator_url'    => is => 'ro', isa => SimpleStr, default => '#';

has 'google_analytics' => is => 'ro', isa => SimpleStr, default => NUL;

has 'image'            => is => 'ro', isa => SimpleStr, default => NUL;

has 'links'            => is => 'ro', isa => ArrayRef[HashRef],
   default             => sub { [] };

has 'repo_url'         => is => 'ro', isa => SimpleStr, default => NUL;

has 'tagline'          => is => 'ro', isa => SimpleStr, default => NUL;

has 'theme'            => is => 'ro', isa => NonEmptySimpleStr,
   default             => 'green';

has 'title'            => is => 'ro', isa => NonEmptySimpleStr,
   default             => 'Documentation';

has 'twitter'          => is => 'ro', isa => ArrayRef, default => sub { [] };

1;

__END__

=pod

=encoding utf8

=head1 Name

Daux::Config - One-line description of the modules purpose

=head1 Synopsis

   use Daux::Config;
   # Brief but working code examples

=head1 Version

This documents version v0.1.$Rev: 2 $ of L<Daux::Config>

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
