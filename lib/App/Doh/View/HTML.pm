# @(#)Ident: HTML.pm 2013-11-28 23:57 pjf ;

package App::Doh::View::HTML;

use namespace::sweep;
use version; our $VERSION = qv( sprintf '0.1.%d', q$Rev: 24 $ =~ /\d+/gmx );

use Moo;
use Class::Usul::Constants;
use Class::Usul::Functions  qw( base64_encode_ns merge_attributes throw );
use Encode;
use File::DataClass::Types  qw( Directory HashRef Object );
use File::Spec::Functions   qw( catfile );
use Module::Pluggable::Object;
use Scalar::Util            qw( weaken );
use Storable                qw( nfreeze );
use Template;

extends q(App::Doh);

# Public attributes
has 'formatters' => is => 'lazy', isa => HashRef, builder => sub {
   my $self = shift; my $formatters = {};

   my $finder = Module::Pluggable::Object->new
      ( search_path => [ __PACKAGE__ ], require => TRUE, );

   for my $formatter ($finder->plugins) {
      my $format = lc ((split m{ :: }mx, $formatter)[ -1 ]);

      $formatters->{ $format } = $formatter->new( builder => $self->_usul );
   }

   return $formatters;
};

has 'skin_dir' => is => 'lazy', isa => Directory,
   builder     => sub { $_[ 0 ]->config->root->catdir( 'skins' ) },
   coerce      => Directory->coercion;

has 'template' => is => 'lazy', isa => Object, builder => sub {
   my $self =  shift;
   my $args =  {
      RELATIVE     => TRUE,
      INCLUDE_PATH => [ $self->skin_dir->pathname ],
      WRAPPER      => catfile( qw( default wrapper.tt ) ), };
   my $template =  Template->new( $args ) or throw $Template::ERROR;

   return $template;
};

has 'type_map' => is => 'lazy', isa => HashRef, builder => sub {
   my $self = shift; my $map = { htm => 'html', html => 'html' };

   for my $format (keys %{ $self->formatters }) {
      for my $extn (@{ $self->formatters->{ $format }->extensions }) {
         $map->{ $extn } = $format;
      }
   }

   return $map;
};

# Public methods
sub render {
   my ($self, $req, $stash) = @_; weaken( $req );

   my $text     = NUL;
   my $prefs    = $stash->{prefs} || {};
   my $cookie   = $self->_serialize_preferences( $req, $prefs );
   my $header   = [ 'Content-Type', 'text/html', 'Set-Cookie', $cookie ];
   my $skin     = $stash->{skin} = $prefs->{skin} || $self->config->skin;
   my $template = ($stash->{template} ||= $self->config->template).'.tt';
   my $path     = $self->skin_dir->catdir( $skin )->catfile( $template );

   unless ($path->exists) {
      $self->log->error( $text = $req->loc( 'Path [_1] not found', $path ) );
      return [ 500, $header, [ $text ] ];
   }

   $self->_render_microformat( $req, $stash->{page} ||= {} );
   $stash->{config } = $self->config;
   $stash->{env    } = $req->env;
   $stash->{loc    } = sub { $req->loc( @_ ) };
   $stash->{uri_for} = sub { $req->uri_for( @_ ) };

   $self->template->process( catfile( $skin, $template ), $stash, \$text )
      or return [ 500, $header, [ $self->template->error ] ];

   return [ 200, $header, [ encode( 'UTF-8', $text ) ] ];
}

# Private methods
sub _render_microformat {
   my ($self, $req, $page) = @_; defined $page->{format} or return;

   $page->{format} eq 'text'
      and $page->{content} = '<pre>'.$page->{content}.'</pre>'
      and $page->{format } = 'html'
      and return;

   my $formatter = $self->formatters->{ $page->{format} } or return;

   $page->{content} = $formatter->render( $req, $page )
      and $page->{format} = 'html';

   return;
}

sub _serialize_preferences {
   my ($self, $req, $prefs) = @_; my $value = base64_encode_ns nfreeze $prefs;

   return CGI::Simple::Cookie->new( -domain  => $req->domain,
                                    -expires => '+3M',
                                    -name    => $self->config->name.'_prefs',
                                    -path    => $req->path,
                                    -value   => $value, );
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
