package App::Doh::Role::Templates;

use namespace::sweep;

use Class::Usul::Constants;
use Class::Usul::Functions qw( throw );
use File::DataClass::Types qw( Directory NonEmptySimpleStr Object );
use File::Spec::Functions  qw( catfile );
use Template;
use Moo::Role;

requires qw( config );

has 'encoder'      => is => 'lazy', isa => Object, builder => sub {
   my $self        =  shift;
   my $args        =  {
      COMPILE_DIR  => $self->config->tempdir->catdir( 'ttc' ),
      COMPILE_EXT  => 'c',
      ENCODING     => 'utf8',
      RELATIVE     => TRUE,
      INCLUDE_PATH => [ $self->templates->pathname ],
      WRAPPER      => catfile( $self->config->default_skin, 'wrapper.tt' ), };
   my $template    =  Template->new( $args ) or throw $Template::ERROR;

   return $template;
};

has 'templates'    => is => 'lazy', isa => Directory,
   builder         => sub { $_[ 0 ]->config->root->catdir( 'templates' ) },
   coerce          => Directory->coercion;

# Public methods
sub render_template {
   my ($self, $req, $stash) = @_;

   my $html     =  NUL;
   my $prefs    =  $stash->{prefs } // {};
   my $conf     =  $stash->{config} = $self->config;
   my $skin     =  $stash->{skin  } = $prefs->{skin} // $conf->skin;
   my $meta     =  $stash->{page  }->{meta} // {};
   my $template = ($meta->{template} // $conf->template).'.tt';
   my $path     =  $self->templates->catdir( $skin )->catfile( $template );

   $path->exists or throw $req->loc( 'Path [_1] not found', $path );
   $self->encoder->process( catfile( $skin, $template ), $stash, \$html )
      or throw $self->encoder->error;

   return $html;
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
