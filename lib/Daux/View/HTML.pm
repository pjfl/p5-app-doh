# @(#)Ident: HTML.pm 2013-07-14 18:36 pjf ;

package Daux::View::HTML;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 4 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Functions  qw( merge_attributes throw );
use Encode;
use File::DataClass::Types  qw( Directory Object );
use Moo;
use Scalar::Util            qw( weaken );
use Template;
use Text::Markdown;

# Public attributes
has 'tm'       => is => 'lazy', isa => Object,
   default     => sub { Text::Markdown->new( tab_width => 3 ) };

has 'skin_dir' => is => 'lazy', isa => Directory, coerce => Directory->coercion,
   default     => sub { $_[ 0 ]->config->root->catdir( 'skins' ) };

has 'template' => is => 'lazy', isa => Object,
   default     => sub {
      Template->new( $_[ 0 ]->_template_args ) or throw $Template::ERROR };

# Private attributes
has '_usul'    => is => 'ro',   isa => Object,
   handles     => [ qw( config loc log ) ], init_arg => 'builder',
   required    => TRUE, weak_ref => TRUE;

# Public methods
sub render {
   my ($self, $stash) = @_;

   my $text     = NUL;
   my $skin     = delete $stash->{skin    } || 'default';
   my $template = delete $stash->{template} || 'layout.tt';

   $template = $self->skin_dir->catdir( $skin )->catfile( $template );

   unless ($template->exists) {
      my $msg = $self->loc( 'Path [_1] not found', $template );

      $self->log->error( $msg ); return [ 500, $msg ];
   }

   my $page = $stash->{page};

   $page->{format} eq 'markdown'
      and $page->{content} = $self->tm->markdown( $page->{content} );

   $self->template->process( $template->pathname, $stash, \$text )
      or return [ 500, $self->template->error ];

   return [ 200, encode( 'UTF-8', $text ) ];
}

# Private methods
sub _template_args {
   my $self = shift; weaken( $self ); my $args = { ABSOLUTE => TRUE, };

   $args->{VARIABLES}->{loc} = sub { $self->loc( @_ ) };

   return $args;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

Daux::View::HTML - One-line description of the modules purpose

=head1 Synopsis

   use Daux::View::HTML;
   # Brief but working code examples

=head1 Version

This documents version v0.1.$Rev: 4 $ of L<Daux::View::HTML>

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
