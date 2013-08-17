# @(#)Ident: Config.pm 2013-08-07 15:04 pjf ;

package Doh::Config;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 15 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use File::DataClass::Types  qw( ArrayRef Directory HashRef NonEmptySimpleStr
                                NonNumericSimpleStr NonZeroPositiveInt
                                SimpleStr );
use Moo;

extends q(Class::Usul::Config::Programs);

has 'author'           => is => 'ro',   isa => NonEmptySimpleStr,
   default             => 'Dave';

has 'brand'            => is => 'ro',   isa => SimpleStr, default => NUL;

has 'colours'          => is => 'lazy', isa => ArrayRef, init_arg => undef;

has 'css'              => is => 'ro',   isa => NonEmptySimpleStr,
   default             => '/css/';

has 'description'      => is => 'ro',   isa => SimpleStr, default => NUL;

has 'docs_path'        => is => 'lazy', isa => Directory,
   coerce              => Directory->coercion,
   default             => sub { $_[ 0 ]->root->catdir( 'docs' ) };

has 'float'            => is => 'ro',   isa => NonNumericSimpleStr,
   coerce              => sub { $_[ 0 ] ? 'float-view' : NUL }, default => TRUE;

has 'font'             => is => 'ro',   isa => SimpleStr,
   default             => sub {
      'http://fonts.googleapis.com/css?family=Roboto+Slab:400,700,300,100' };

has 'generator_url'    => is => 'ro',   isa => SimpleStr, default => '#';

has 'google_analytics' => is => 'ro',   isa => SimpleStr, default => NUL;

has 'images'           => is => 'ro',   isa => NonEmptySimpleStr,
   default             => '/img/';

has 'js'               => is => 'ro',   isa => NonEmptySimpleStr,
   default             => '/js/';

has 'keywords'         => is => 'ro',   isa => SimpleStr, default => NUL;

has 'less'             => is => 'ro',   isa => NonEmptySimpleStr,
   default             => '/less/';

has 'links'            => is => 'lazy', isa => ArrayRef, init_arg => undef;

has 'mount_point'      => is => 'ro',   isa => NonEmptySimpleStr,
   default             => '/';

has 'no_index'         => is => 'ro',   isa => ArrayRef,
   default             => sub { [ qw( .git .svn cgi-bin doh.json ) ] };

has 'port'             => is => 'lazy', isa => NonZeroPositiveInt,
   default             => 8085;

has 'preferences'      => is => 'ro',   isa => ArrayRef,
   default             => sub { [ qw( float theme ) ] };

has 'projects'         => is => 'ro',   isa => HashRef,   default => sub { {} };

has 'repo_url'         => is => 'ro',   isa => SimpleStr, default => NUL;

has 'server'           => is => 'ro',   isa => NonEmptySimpleStr,
   default             => 'Twiggy';

has 'theme'            => is => 'ro',   isa => NonEmptySimpleStr,
   default             => 'green';

has 'title'            => is => 'ro',   isa => NonEmptySimpleStr,
   default             => 'Documentation';

has 'twitter'          => is => 'ro',   isa => ArrayRef,  default => sub { [] };


has '_colours'         => is => 'ro',   isa => HashRef,
   default             => sub { {} }, init_arg => 'colours';

has '_links'           => is => 'ro',   isa => HashRef,
   default             => sub { {} }, init_arg => 'links';

sub _build_colours {
   return __to_array_of_hash( $_[ 0 ]->_colours, qw( key value ) );
}

sub _build_links {
   return __to_array_of_hash( $_[ 0 ]->_links, qw( name url ) );
}

sub __to_array_of_hash {
   my ($href, $key_key, $val_key) = @_;

   return [ map { my $v = $href->{ $_ }; +{ $key_key => $_, $val_key => $v } }
            sort keys %{ $href } ],
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Doh::Config - One-line description of the modules purpose

=head1 Synopsis

   use Doh::Config;
   # Brief but working code examples

=head1 Version

This documents version v0.1.$Rev: 15 $ of L<Doh::Config>

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
