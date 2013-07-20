# @(#)Ident: HTML.pm 2013-07-20 03:28 pjf ;

package Doh::View::HTML;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 9 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Functions  qw( merge_attributes throw );
use Doh::View::HTML::POD;
use Encode;
use File::DataClass::Types  qw( Directory Object );
use File::Spec::Functions   qw( catfile );
use Moo;
use Scalar::Util            qw( weaken );
use Template;
use Text::Markdown;

extends q(Doh);

# Public attributes
has 'pod'      => is => 'lazy', isa => Object,
   default     => sub { Doh::View::HTML::POD->new( builder => $_[ 0 ]->_usul )};

has 'tm'       => is => 'lazy', isa => Object,
   default     => sub { Text::Markdown->new( tab_width => 3 ) };

has 'skin_dir' => is => 'lazy', isa => Directory, coerce => Directory->coercion,
   default     => sub { $_[ 0 ]->config->root->catdir( 'skins' ) };

has 'template' => is => 'lazy', isa => Object,
   default     => sub { Template->new( $_[ 0 ]->_template_args )
                           or throw $Template::ERROR };

# Public methods
sub render {
   my ($self, $stash) = @_;

   my $text     = NUL;
   my $skin     = delete $stash->{skin    } || 'default';
   my $template = delete $stash->{template} || 'index.tt';
   my $path     = $self->skin_dir->catdir( $skin )->catfile( $template );

   unless ($path->exists) {
      my $msg = $self->loc( 'Path [_1] not found', $path );

      $self->log->error( $msg ); return [ 500, $msg ];
   }

   my $page = $stash->{page} ||= {};

   defined $page->{format} and $self->render_microformat( $page );

   $self->template->process( catfile( $skin, $template ), $stash, \$text )
      or return [ 500, $self->template->error ];

   return [ 200, encode( 'UTF-8', $text ) ];
}

sub render_microformat {
   my ($self, $page) = @_;

   $page->{format} eq 'markdown'
      and $page->{content} = $self->tm->markdown( $page->{content} )
      and $page->{format } = 'html';
   $page->{format} eq 'pod'
      and $page->{content} = $self->pod->render( $page->{content} )
      and $page->{format } = 'html';
   return $page;
}

# Private methods
sub _template_args {
   my $self = shift; weaken( $self );

   return { RELATIVE     => TRUE,
            INCLUDE_PATH => [ $self->skin_dir->pathname ],
            VARIABLES    => { loc => sub { $self->loc( @_ ) } },
            WRAPPER      => catfile( qw( default wrapper.tt ) ), };
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Doh::View::HTML - One-line description of the modules purpose

=head1 Synopsis

   use Doh::View::HTML;
   # Brief but working code examples

=head1 Version

This documents version v0.1.$Rev: 9 $ of L<Doh::View::HTML>

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
