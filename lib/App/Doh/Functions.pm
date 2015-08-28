package App::Doh::Functions;

use 5.010001;
use strictures;
use parent  'Exporter::Tiny';

use Class::Usul::Constants       qw( FALSE NUL TRUE );
use Class::Usul::Functions       qw( env_prefix first_char is_arrayref
                                     is_hashref );
use English                      qw( -no_match_vars );
use Web::ComposableRequest::Util qw( extract_lang );

our @EXPORT_OK = qw( build_navigation_list build_tree clone env_var is_static
                     iterator localise_tree make_id_from make_name_from mtime
                     set_element_focus show_node );

# Private functions
my $extension2format = sub {
   my ($map, $path) = @_; my $extn = (split m{ \. }mx, $path)[ -1 ] || NUL;

   return $map->{ $extn } // 'text';
};

my $get_tip_text = sub {
   my ($root, $node) = @_; my $text = $node->{path}->abs2rel( $root );

   $text =~ s{ \A [a-z]+ / }{}mx; $text =~ s{ \. .+ \z }{}mx;
   $text =~ s{ [/] }{ / }gmx;     $text =~ s{ [_] }{ }gmx;

   return $text;
};

my $sorted_keys = sub {
   my $node = shift;

   return [ sort { $node->{ $a }->{_order} <=> $node->{ $b }->{_order} }
            grep { first_char $_ ne '_' } keys %{ $node } ];
};

my $make_tuple = sub {
   my $node = shift; my $is_folder = $node && $node->{type} eq 'folder' ? 1 : 0;

   return [ 0, $is_folder ? $sorted_keys->( $node->{tree} ) : [], $node, ];
};

# Public functions
sub build_navigation_list ($$$$) {
   my ($root, $tree, $ids, $wanted) = @_;

   my $iter = iterator( $tree ); my @nav = ();

   while (defined (my $node = $iter->())) {
      $node->{id} eq 'index' and next;

      my $link = clone( $node ); delete $link->{tree};

      $link->{class}  = $node->{type} eq 'folder' ? 'folder-link' : 'file-link';
      $link->{tip  }  = $get_tip_text->( $root, $node );
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
   my ($map, $dir, $depth, $node_order, $url_base, $parent) = @_;

   $depth //= 0; $node_order //= 0; $url_base //= NUL; $parent //= NUL;

   my $fcount = 0; my $max_mtime = 0; my $tree = {}; $depth++;

   for my $path ($dir->all) {
      my ($id, $pref) =  @{ make_id_from( $path->utf8->filename ) };
      my  $name       =  make_name_from( $id );
      my  $url        =  $url_base ? "${url_base}/${id}" : $id;
      my  $mtime      =  $path->stat->{mtime};
      my  $node       =  $tree->{ $id } = {
          date        => $mtime,
          depth       => $depth,
          format      => $extension2format->( $map, "${path}" ),
          id          => $id,
          name        => $name,
          parent      => $parent,
          path        => $path,
          prefix      => $pref,
          title       => ucfirst $name,
          type        => 'file',
          url         => $url,
          _order      => $node_order++, };

      $path->is_file and $fcount++ and $mtime > $max_mtime
                                   and $max_mtime = $mtime;
      $path->is_dir or next;
      $node->{type} = 'folder';
      $node->{tree} = $depth > 1 # Skip the language code directories
         ?  build_tree( $map, $path, $depth, $node_order, $url, $name )
         :  build_tree( $map, $path, $depth, $node_order );
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

sub env_var ($$;$) {
   my ($class, $var, $v) = @_; my $k = (env_prefix $class)."_${var}";

   return defined $v ? $ENV{ $k } = $v : $ENV{ $k };
}

sub is_static ($) {
   return !env_var( $_[ 0 ], 'MAKE_STATIC' ) ? FALSE : TRUE;
}

sub iterator ($) {
   my $tree = shift; my @folders = ( $make_tuple->( $tree ) );

   return sub {
      while (my $tuple = $folders[ 0 ]) {
         while (defined (my $k = $tuple->[ 1 ]->[ $tuple->[ 0 ]++ ])) {
            my $node = $tuple->[ 2 ]->{tree}->{ $k };

            $node->{type} eq 'folder'
               and unshift @folders, $make_tuple->( $node );

            return $node;
         }

         shift @folders;
      }

      return;
   };
}

sub localise_tree ($$) {
   my ($tree, $locale) = @_; ($tree and $locale) or return FALSE;

   exists $tree->{ $locale } and defined $tree->{ $locale }
      and return $tree->{ $locale };

   my $lang = extract_lang $locale;

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
