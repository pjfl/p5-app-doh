# @(#)Ident: POD.pm 2013-07-19 23:33 pjf ;

package Doh::View::HTML::POD;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 9 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Types      qw( NonEmptySimpleStr Object Str );
use HTML::Accessors;
use Moo;
use Pod::Hyperlink::BounceURL;
use Pod::Xhtml;

extends q(Doh);

has 'link_text' => is => 'ro',   isa => NonEmptySimpleStr,
   default      => 'Back to Top';


has '_hacc'     => is => 'lazy', isa => Object,
   default      => sub { HTML::Accessors->new( content_type => 'text/html' ) };

has '_top_link' => is => 'lazy', isa => Str;

sub render {
   my ($self, $args) = @_;

   my $hacc        = $self->_hacc;
   my $anchor      = $hacc->a( { id => 'podtop' } );
   my $title       = $hacc->h1( $args->{title} );
   my $heading     = $anchor.$hacc->div( { class => 'page-header' }, $title );
   my $link_parser = Pod::Hyperlink::BounceURL->new;
      $link_parser->configure( URL => $args->{url} );
   my $parser      = Pod::Xhtml->new( FragmentOnly => TRUE,
                                      LinkParser   => $link_parser,
                                      StringMode   => TRUE,
                                      TopHeading   => 2,
                                      TopLinks     => $self->_top_link, );

   $parser->parse_from_file( $args->{src} );

   return $heading.$parser->asString;
}

sub _build__top_link {
   my $self = shift;
   my $hacc = $self->_hacc;
   my $attr = { class => 'toplink', href => '#podtop' };
   my $link = $hacc->a( $attr, $self->loc( $self->link_text ) );

   return $hacc->p( { class => 'toplink' }, $link );
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Doh::View::HTML::POD - One-line description of the modules purpose

=head1 Synopsis

   use Doh::View::HTML::POD;
   # Brief but working code examples

=head1 Version

This documents version v0.1.$Rev: 9 $ of L<Doh::View::HTML::POD>

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
