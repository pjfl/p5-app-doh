# @(#)Ident: Help.pm 2013-07-18 18:49 pjf ;

package Doh::Model::Help;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 8 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Functions  qw( is_hashref trim );
use File::DataClass::Types  qw( Object );
use Moo;

extends q(Doh);

sub get_stash {
   my ($self, @args) = @_;

   my $conf  = $self->config;
   my $env   = ($args[ -1 ] && is_hashref $args[ -1 ]) ? pop @args : {};
   my @parts = split m{ [/] }mx, trim $args[ 0 ] || 'index', '/';

   return {
      colours      => __to_array_of_hash( $conf->colours, qw( key value ) ),
      config       => $conf,
      homepage     => FALSE,
      links        => __to_array_of_hash( $conf->links, qw( name url ) ),
      nav          => [],
      page         => { content => { src   => $self->config->appldir->catfile( qw( lib Doh.pm ) )->pathname,
                                     title => 'Help',
                                     url   => 'https://metacpan.org/module/', },
                        format  => 'pod', },
   };
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

Doh::Model::Help - One-line description of the modules purpose

=head1 Synopsis

   use Doh::Model::Help;
   # Brief but working code examples

=head1 Version

This documents version v0.1.$Rev: 8 $ of L<Doh::Model::Help>

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
