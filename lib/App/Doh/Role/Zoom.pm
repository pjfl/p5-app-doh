package App::Doh::Role::Zoom;

use namespace::autoclean;

use Class::Usul::Constants;
use Class::Usul::Functions qw( throw );
use HTML::Zoom;
use Scalar::Util           qw( weaken );
use Moo::Role;

# Public methods
sub render_template {
   my ($self, $req, $stash) = @_; weaken( $req ); weaken( $stash );

   my $prefs     =  $stash->{prefs } // {};
   my $conf      =  $stash->{config} = $self->config;
   my $skin      =  $stash->{skin  } = $prefs->{skin} // $conf->skin;
   my $page      =  $stash->{page  } // {};
   my $layout    = ($page->{layout} //= $conf->layout).'.html';
   my $templates =  $self->templates->catdir( $skin );
   my $path      =  $templates->catfile( $layout );

   $path->exists or throw class => PathNotFound, args => [ $path ];

   my $content = HTML::Zoom->from_file( $path );

   $stash->{content_only} and return $content->to_html;

   my $wrapper = HTML::Zoom->from_file( $templates->catfile( 'wrapper.html' ) )
                           ->apply( sub { __wrapper( $_, $req, $stash ) } );

   return $wrapper->select( 'body' )->replace_content( $content )->to_html;
}

sub __wrapper {
   my ($z, $req, $stash) = @_;

   my $conf  = $stash->{config};
   my $links = $stash->{links };
   my $page  = $stash->{page  };
   my $prefs = $stash->{prefs };
   my $icon  = $conf->{colours}->[ 0 ] ? 'favicon' : 'favicon-'.$prefs->{theme};
   my $title = $conf->{title  }.' - '.$req->loc( $page->{title} );

   $z = $z->select( 'html' )
          ->set_attribute( 'lang', $page->{language} )
          ->select( 'meta[name="description"]' )
          ->set_attribute( 'content', $req->loc( $page->{description} ) )
          ->select( 'meta[name="keywords"]' )
          ->set_attribute( 'content', $page->{keywords} )
          ->select( 'meta[name="author"]' )
          ->set_attribute( 'content', $page->{author} )
          ->select( 'meta[name="generator"]' )
          ->set_attribute( 'content', 'Doh v'.$page->{application_version} )
          ->select( 'link[rel="icon"]' )
          ->set_attribute( 'href', $links->{images}.$icon.'.png' )
          ->select( 'title' )->replace_content( $title );

   my @sheets; $conf->{font} and push @sheets, $conf->{font};

   not $conf->{colours}->[ 0 ]
      and push @sheets, $links->{css}.'theme-'.$prefs->{theme}.'.css';

   $sheets[ 0 ] and $z = $z->select( 'html' )
                           ->repeat( [ map { my $href = $_; sub {
                              $_->select( 'link[rel="stylesheet"]' )
                                ->set_attribute( 'href', $href ) } } @sheets ]);

   return $z;
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
