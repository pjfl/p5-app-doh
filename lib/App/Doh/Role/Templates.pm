package App::Doh::Role::Templates;

use namespace::autoclean;

use Class::Usul::Constants qw( EXCEPTION_CLASS NUL TRUE );
use Class::Usul::Functions qw( throw );
use File::DataClass::Types qw( Directory NonEmptySimpleStr Object );
use File::Spec::Functions  qw( catfile );
use Template;
use Unexpected::Functions  qw( PathNotFound );
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
      WRAPPER      => catfile( $self->config->skin, 'wrapper.tt' ), };
   my $template    =  Template->new( $args ) or throw $Template::ERROR;

   return $template;
};

has 'templates'    => is => 'lazy', isa => Directory,
   builder         => sub { $_[ 0 ]->config->root->catdir( 'templates' ) },
   coerce          => Directory->coercion;

# Public methods
sub render_template {
   my ($self, $req, $stash) = @_;

   my $result =  NUL;
   my $prefs  =  $stash->{prefs } // {};
   my $conf   =  $stash->{config} = $self->config;
   my $skin   =  $stash->{skin  } = $prefs->{skin} // $conf->skin;
   my $page   =  $stash->{page  } // {};
   my $layout = ($page->{layout} //= $conf->layout).'.tt';
   my $path   =  $self->templates->catdir( $skin )->catfile( $layout );
   my $funcs  = (delete $stash->{functions}) // {};

   $stash->{ $_ } = $funcs->{ $_ } for (keys %{ $funcs });

   $path->exists or throw class => PathNotFound, args => [ $path ];
   $self->encoder->process( catfile( $skin, $layout ), $stash, \$result )
      or throw $self->encoder->error;

   return $result;
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
