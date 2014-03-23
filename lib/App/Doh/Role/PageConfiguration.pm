package App::Doh::Role::PageConfiguration;

use namespace::sweep;

use Moo::Role;

requires qw( config load_page );

# Construction
around 'load_page' => sub {
   my ($orig, $self, $req) = @_; my $page = $orig->( $self, $req );

   my $conf = $self->config;

   $page->{ $_ } = $conf->$_() for (qw( author description keywords ));

   return $page;
};

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
