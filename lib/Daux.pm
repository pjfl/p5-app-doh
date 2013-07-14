# @(#)Ident: Daux.pm 2013-07-14 02:04 pjf ;

package Daux;

use 5.01;
use strict;
use warnings;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 2 $ =~ /\d+/gmx );

use Class::Usul;
use Class::Usul::Constants;
use Class::Usul::Functions  qw( find_apphome get_cfgfiles );
use Daux::Model::Documentation;
use Daux::View::HTML;
use Scalar::Util            qw( blessed );
use Web::Simple;

my $EXTNS = [ qw( .json ) ];

has 'appclass'  => is => 'ro';
has 'html_view' => is => 'lazy';
has 'model'     => is => 'lazy';
has 'usul'      => is => 'lazy';

sub dispatch_request {
   sub (GET + / | /**) {
      my ($self, @args) = @_;
      my $stash = $self->model->get_stash( @args );
      my $res   = $self->html_view->render( $stash );

      return [ $res->[ 0 ], [ 'Content-type', 'text/html' ], [ $res->[ 1 ] ] ];
   };
}

# Private methods
sub _build_html_view {
   return Daux::View::HTML->new( builder => $_[ 0 ]->usul );
}

sub _build_model {
   return Daux::Model::Documentation->new( builder => $_[ 0 ]->usul );
}

sub _build_usul {
   my $self = shift;
   my $attr = { config => {}, config_class => 'Daux::Config' };
   my $conf = $attr->{config};

   $conf->{appclass} = $self->appclass || blessed $self || $self;
   $conf->{home    } = find_apphome( $conf->{appclass}, NUL, $EXTNS );
   $conf->{cfgfiles} = get_cfgfiles( $conf->{appclass}, $conf->{home}, $EXTNS );

   return Class::Usul->new( $attr );
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Daux - One-line description of the modules purpose

=head1 Synopsis

   use Daux;
   # Brief but working code examples

=head1 Version

This documents version v0.1.$Rev: 2 $ of L<Daux>

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
