# @(#)Ident: HTML.pm 2013-07-22 23:33 pjf ;

package Doh::View::HTML;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 13 $ =~ /\d+/gmx );

use Class::Usul::Constants;
use Class::Usul::Functions  qw( merge_attributes throw );
use Encode;
use File::DataClass::Types  qw( Directory HashRef Object );
use File::Spec::Functions   qw( catfile );
use Module::Pluggable::Object;
use Moo;
use Scalar::Util            qw( weaken );
use Template;

extends q(Doh);

# Public attributes
has 'formatters' => is => 'lazy', isa => HashRef;

has 'skin_dir'   => is => 'lazy', isa => Directory,
   default       => sub { $_[ 0 ]->config->root->catdir( 'skins' ) },
   coerce        => Directory->coercion;

has 'template'   => is => 'lazy', isa => Object,
   default       => sub { Template->new( $_[ 0 ]->_template_args )
                             or throw $Template::ERROR };

has 'type_map'   => is => 'lazy', isa => HashRef;

# Public methods
sub render {
   my ($self, $stash) = @_;

   my $text     = NUL;
   my $header   = [ 'Content-Type', 'text/html' ];
   my $skin     =  delete $stash->{skin    } || 'default';
   my $template = (delete $stash->{template} || 'index').'.tt';
   my $path     = $self->skin_dir->catdir( $skin )->catfile( $template );

   unless ($path->exists) {
      $self->log->error( $text = $self->loc( 'Path [_1] not found', $path ) );
      return [ 500, $header, [ $text ] ];
   }

   $self->_render_microformat( $stash->{page} ||= {} );

   $self->template->process( catfile( $skin, $template ), $stash, \$text )
      or return [ 500, $header, [ $self->template->error ] ];

   return [ 200, $header, [ encode( 'UTF-8', $text ) ] ];
}

# Private methods
sub _build_formatters {
   my $self = shift; my $formatters = {};

   my $finder = Module::Pluggable::Object->new
      ( search_path => [ __PACKAGE__ ], require => TRUE, );

   for my $formatter ($finder->plugins) {
      my $format = lc ((split m{ :: }mx, $formatter)[ -1 ]);

      $formatters->{ $format } = $formatter->new( builder => $self->_usul );
   }

   return $formatters;
}

sub _build_type_map {
   my $self = shift; my $map = { htm => 'html', html => 'html' };

   for my $format (keys %{ $self->formatters }) {
      for my $extn (@{ $self->formatters->{ $format }->extensions }) {
         $map->{ $extn } = $format;
      }
   }

   return $map;
}

sub _render_microformat {
   my ($self, $page) = @_; defined $page->{format} or return;

   $page->{format} eq 'text'
      and $page->{content} = '<pre>'.$page->{content}.'</pre>'
      and $page->{format } = 'html'
      and return;

   my $formatter = $self->formatters->{ $page->{format} } or return;

   $page->{content} = $formatter->render( $page ) and $page->{format} = 'html';

   return;
}

sub _template_args {
   my $self = shift; weaken( $self );

   return { RELATIVE     => TRUE,
            INCLUDE_PATH => [ $self->skin_dir->pathname ],
            VARIABLES    => { loc => sub { $self->loc( @_ ) } },
            WRAPPER      => catfile( qw( default wrapper.tt ) ), };
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
