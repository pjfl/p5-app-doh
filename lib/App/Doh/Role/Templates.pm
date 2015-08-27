package App::Doh::Role::Templates;

use namespace::autoclean;

use App::Doh::Functions    qw( show_node );
use Class::Usul::Constants qw( EXCEPTION_CLASS NUL TRUE );
use Class::Usul::Functions qw( is_member throw );
use Class::Usul::Time      qw( str2time time2str );
use File::DataClass::Types qw( Directory Object );
use File::Spec::Functions  qw( catfile );
use Scalar::Util           qw( weaken );
use Template;
use Unexpected::Functions  qw( PathNotFound );
use Moo::Role;

requires qw( config );

# Attribute constructors
my $_build_encoder =  sub {
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

has 'encoder'   => is => 'lazy', isa => Object, builder => $_build_encoder;

has 'templates' => is => 'lazy', isa => Directory, coerce => TRUE,
   builder      => sub { $_[ 0 ]->config->root->catdir( 'templates' ) };

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

   $path->exists or throw PathNotFound, [ $path ];
   $self->encoder->process( catfile( $skin, $layout ), $stash, \$result )
      or throw $self->encoder->error;

   return $result;
}

around 'render_template' => sub {
   my ($orig, $self, $req, $stash) = @_; weaken( $req );

   $stash->{is_member} = \&is_member;
   $stash->{loc      } = sub { $req->loc( @_ ) };
   $stash->{show_node} = \&show_node;
   $stash->{str2time } = \&str2time;
   $stash->{time2str } = \&time2str;
   $stash->{ucfirst  } = sub { ucfirst $_[ 0 ] };
   $stash->{uri_for  } = sub { $req->uri_for( @_ ), };

   return $orig->( $self, $req, $stash );
};

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
