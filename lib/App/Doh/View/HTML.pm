package App::Doh::View::HTML;

use namespace::sweep;

use Moo;
use Class::Usul::Constants;
use Class::Usul::Functions qw( throw );
use Class::Usul::Time      qw( time2str );
use Encode;
use File::DataClass::Types qw( Directory HashRef Object );
use File::Spec::Functions  qw( catfile );
use Module::Pluggable::Object;
use Scalar::Util           qw( weaken );
use Template;

extends q(App::Doh);

# Public attributes
has 'formatters' => is => 'lazy', isa => HashRef[Object], builder => sub {
   my $self = shift; my $formatters = {};

   my $finder = Module::Pluggable::Object->new
      ( search_path => [ __PACKAGE__ ], require => TRUE, );

   for my $formatter ($finder->plugins) {
      my $format = lc ((split m{ :: }mx, $formatter)[ -1 ]);

      $formatters->{ $format } = $formatter->new( builder => $self->usul );
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
sub serialize {
   my ($self, $req, $stash) = @_; weaken( $req );

   my $html     = NUL;
   my $prefs    = $stash->{prefs } // {};
   my $conf     = $stash->{config} = $self->config;
   my $skin     = $stash->{skin  } = $prefs->{skin} // $conf->skin;
   my $header   = __header( $stash->{http_headers} );
   my $template = ($stash->{template} ||= $conf->template).'.tt';
   my $path     = $self->skin_dir->catdir( $skin )->catfile( $template );

   unless ($path->exists) {
      $self->log->error( $html = $req->loc( 'Path [_1] not found', $path ) );
      return [ 500, $header, [ $html ] ];
   }

   $self->_serialize_microformat( $req, $stash->{page} //= {} );
   $stash->{req     } = $req;
   $stash->{loc     } = sub { $req->loc( @_ ) };
   $stash->{time2str} = sub { time2str( $_[ 0 ], $_[ 1 ], $_[ 2 ] ) };
   $stash->{uri_for } = sub { $req->uri_for( @_ ) };

   $self->template->process( catfile( $skin, $template ), $stash, \$html )
      or return [ 500, $header, [ $self->template->error ] ];

   return [ 200, $header, [ encode( 'UTF-8', $html ) ] ];
}

# Private methods
sub _serialize_microformat {
   my ($self, $req, $page) = @_; defined $page->{format} or return;

   $page->{format} eq 'text'
      and $page->{content} = '<pre>'.$page->{content}.'</pre>'
      and $page->{format } = 'html'
      and return;

   my $formatter = $self->formatters->{ $page->{format} } or return;

   $page->{content} = $formatter->serialize( $req, $page )
      and $page->{format} = 'html';

   return;
}

# Private functions
sub __header {
   return [ 'Content-Type' => 'text/html', @{ $_[ 0 ] || [] } ];
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
