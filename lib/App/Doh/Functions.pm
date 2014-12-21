package App::Doh::Functions;

use 5.010001;
use strictures;
use feature 'state';
use parent  'Exporter::Tiny';

use Class::Usul::Constants qw( FALSE LANG NUL TRUE );
use Class::Usul::Functions qw( first_char is_arrayref is_hashref
                               my_prefix split_on_dash );
use English                qw( -no_match_vars );
use Module::Pluggable::Object;
use URI::Escape            qw( );
use URI::http;
use URI::https;

our @EXPORT_OK = qw( build_navigation_list build_tree clone  env_var
                     extract_lang is_static iterator load_components
                     localise_tree make_id_from make_name_from mtime
                     new_uri set_element_focus show_node );

my $reserved   = q(;/?:@&=+$,[]);
my $mark       = q(-_.!~*'());                                    #'; emacs
my $unreserved = "A-Za-z0-9\Q${mark}\E";
my $uric       = quotemeta( $reserved )."${unreserved}%";

# Private functions
my $_extension2format = sub {
   my ($map, $path) = @_; my $extn = (split m{ \. }mx, $path)[ -1 ] || NUL;

   return $map->{ $extn } // 'text';
};

my $_get_tip_text = sub {
   my ($root, $node) = @_; my $text = $node->{path}->abs2rel( $root );

   $text =~ s{ \A [a-z]+ / }{}mx; $text =~ s{ \. .+ \z }{}mx;
   $text =~ s{ [/] }{ / }gmx;     $text =~ s{ [_] }{ }gmx;

   return $text;
};

my $_sorted_keys = sub {
   my $node = shift;

   return [ sort { $node->{ $a }->{_order} <=> $node->{ $b }->{_order} }
            grep { first_char $_ ne '_' } keys %{ $node } ];
};

my $_uric_escape = sub {
    my $str = shift;

    $str =~ s{([^$uric\#])}{ URI::Escape::escape_char($1) }ego;
    utf8::downgrade( $str );
    return \$str;
};

my $_make_tuple = sub {
   my $node = shift; my $is_folder = $node && $node->{type} eq 'folder' ? 1 : 0;

   return [ 0, $is_folder ? $_sorted_keys->( $node->{tree} ) : [], $node, ];
};

# Public functions
sub build_navigation_list ($$$$) {
   my ($root, $tree, $ids, $wanted) = @_;

   my $iter = iterator( $tree ); my @nav = ();

   while (defined (my $node = $iter->())) {
      $node->{id} eq 'index' and next;

      my $link = clone( $node ); delete $link->{tree};

      $link->{class}  = $node->{type} eq 'folder' ? 'folder-link' : 'file-link';
      $link->{tip  }  = $_get_tip_text->( $root, $node );
      $link->{depth} -= 2;

      if (defined $ids->[ 0 ] and $ids->[ 0 ] eq $node->{id}) {
         $link->{class} .= $node->{url} eq $wanted ? ' active' : ' open';
         shift @{ $ids };
      }

      push @nav, $link;
   }

   return \@nav;
}

sub build_tree {
   my ($map, $dir, $depth, $no_reset, $url_base, $parent) = @_;

   $depth //= 0; $depth++; state $order; $no_reset or $order = 0;

   $url_base //= NUL; $parent //= NUL;

   my $fcount = 0; my $max_mtime = 0; my $tree = {};

   for my $path ($dir->all) {
      my ($id, $pref) =  @{ make_id_from( $path->filename ) };
      my  $name       =  make_name_from( $id );
      my  $url        =  $url_base ? "${url_base}/${id}" : $id;
      my  $mtime      =  $path->stat->{mtime};
      my  $node       =  $tree->{ $id } = {
          date        => $mtime,
          depth       => $depth,
          format      => $_extension2format->( $map, $path->pathname ),
          id          => $id,
          name        => $name,
          parent      => $parent,
          path        => $path->utf8,
          prefix      => $pref,
          title       => ucfirst $name,
          type        => 'file',
          url         => $url,
          _order      => $order++, };

      $path->is_file and ++$fcount and $mtime > $max_mtime
                                   and $max_mtime = $mtime;
      $path->is_dir or next;
      $node->{type} =  'folder';
      $node->{tree} =  $depth > 1 # Skip the language code directories
                    ?  build_tree( $map, $path, $depth, $order, $url, $name )
                    :  build_tree( $map, $path, $depth, $order, NUL,  NUL   );
      $fcount += $node->{fcount} = $node->{tree}->{_fcount};
      mtime( $node ) > $max_mtime and $max_mtime = mtime( $node );
   }

   $tree->{_fcount} = $fcount; $tree->{_mtime} = $max_mtime;

   return $tree;
}

sub clone (;$) {
   my $v = shift;

   is_arrayref $v and return [ @{ $v // [] } ];
   is_hashref  $v and return { %{ $v // {} } };
   return $v;
}

sub env_var ($;$) {
   my $k = (uc split_on_dash my_prefix $PROGRAM_NAME).'_'.$_[ 0 ];

   return defined $_[ 1 ] ? $ENV{ $k } = $_[ 1 ] : $ENV{ $k };
}

sub extract_lang ($) {
   my $v = shift; return $v ? (split m{ _ }mx, $v)[ 0 ] : LANG;
}

sub is_static () {
   return !!env_var( 'MAKE_STATIC' ) ? TRUE : FALSE;
}

sub iterator ($) {
   my $tree = shift; my @folders = ( $_make_tuple->( $tree ) );

   return sub {
      while (my $tuple = $folders[ 0 ]) {
         while (defined (my $k = $tuple->[ 1 ]->[ $tuple->[ 0 ]++ ])) {
            my $node = $tuple->[ 2 ]->{tree}->{ $k };

            $node->{type} eq 'folder'
               and unshift @folders, $_make_tuple->( $node );

            return $node;
         }

         shift @folders;
      }

      return;
   };
}

sub load_components ($$) {
   my ($search_path, $args) = @_; my $conf = $args->{builder}->config;

   if (first_char $search_path eq '+') { $search_path = substr $search_path, 1 }
   else { $search_path = $conf->appclass."::${search_path}" }

   my $depth    = () = split m{ :: }mx, $search_path, -1;
   my @depth    = (min_depth => $depth + 1, max_depth => $depth + 1);
   my $finder   = Module::Pluggable::Object->new
      ( @depth, search_path => [ $search_path ], require => TRUE, );
   my $monikers = $conf->monikers;
   my $plugins  = {};

   for my $plugin ($finder->plugins) {
      exists $monikers->{ $plugin } and defined $monikers->{ $plugin }
         and $args->{moniker} = $monikers->{ $plugin };

      my $comp  = $plugin->new( $args ); $plugins->{ $comp->moniker } = $comp;
   }

   return $plugins;
}

sub localise_tree ($$) {
   my ($tree, $locale) = @_;

   exists $tree->{ $locale } and defined $tree->{ $locale }
      and return $tree->{ $locale };

   my $lang = extract_lang( $locale );

   exists $tree->{ $lang } and defined $tree->{ $lang }
      and return $tree->{ $lang };

   return FALSE;
}

sub make_id_from ($) {
   my $v = shift; my ($p) = $v =~ m{ \A ((?: \d+ [_\-] )+) }mx;

   $v =~ s{ \A (\d+ [_\-])+ }{}mx; $v =~ s{ [_] }{-}gmx;

   $v =~ s{ \. [a-zA-Z0-9_\+]+ \z }{}mx;

   defined $p and $p =~ s{ [_\-]+ \z }{}mx;

   return [ $v, $p // NUL ];
}

sub make_name_from ($) {
   my $v = shift; $v =~ s{ [_\-] }{ }gmx; return $v;
}

sub mtime ($) {
   return $_[ 0 ]->{tree}->{_mtime};
}

sub new_uri ($$) {
   return bless $_uric_escape->( $_[ 0 ] ), 'URI::'.$_[ 1 ];
}

sub set_element_focus ($$) {
   my ($form, $name) = @_;

   return [ "var form = document.forms[ '${form}' ];",
            "var f = function() { behaviour.rebuild(); form.${name}.focus() };",
            'f.delay( 100 );', ];
}

sub show_node ($;$$) {
   my ($node, $wanted, $wanted_depth) = @_;

   $wanted //= NUL; $wanted_depth //= 0;

   return $node->{depth} >= $wanted_depth
       && $node->{url  } =~ m{ \A $wanted }mx ? TRUE : FALSE;
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
