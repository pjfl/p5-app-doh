package App::Doh::Role::Templates;

use namespace::autoclean;

use Class::Usul::Constants qw( EXCEPTION_CLASS NUL TRUE );
use Class::Usul::Functions qw( throw );
use File::DataClass::Types qw( Directory Object );
use Template;
use Unexpected::Functions  qw( PathNotFound );
use Moo::Role;

requires qw( config );

# Attribute constructors
my $_build__templater = sub {
   my $self        =  shift;
   my $args        =  {
      COMPILE_DIR  => $self->config->tempdir->catdir( 'ttc' ),
      COMPILE_EXT  => 'c',
      ENCODING     => 'utf8',
      RELATIVE     => TRUE,
      INCLUDE_PATH => [ $self->templates->pathname ], };
   my $template    =  Template->new( $args ) or throw $Template::ERROR;

   return $template;
};

# Public attributes
has 'templates'  => is => 'lazy', isa => Directory, coerce => TRUE,
   builder       => sub { $_[ 0 ]->config->root->catdir( 'templates' ) };

# Private attributes
has '_templater' => is => 'lazy', isa => Object, builder => $_build__templater;

# Public methods
sub render_template {
   my ($self, $req, $stash) = @_;

   my $result =  NUL;
   my $conf   =  $stash->{config} //= $self->config;
   my $skin   =  $stash->{skin  } //= $conf->skin;
   my $page   =  $stash->{page  } //= {};
   my $layout = ($page->{layout } //= $conf->layout).'.tt';
   my $path   =  $self->templates->catfile( $skin, $layout );

   $path->exists or throw PathNotFound, [ $path ];
   $self->_templater->process
      ( $path->abs2rel( $self->templates ), $stash, \$result )
      or throw $self->_templater->error;

   return $result;
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
