package App::Doh::Functions;

use 5.010001;
use strict;
use warnings;
use parent 'Exporter::Tiny';

use Class::Usul::Constants;
use Class::Usul::Functions qw( first_char is_arrayref is_hashref );

our @EXPORT_OK = qw( build_navigation_list build_tree clone extract_lang
                     iterator localise_tree make_id_from make_name_from mtime
                     show_node );

sub build_navigation_list ($$$$) {
   my ($root, $tree, $ids, $wanted) = @_;

   my $iter = iterator( $tree ); my @nav = ();

   while (defined (my $node = $iter->())) {
      $node->{id} eq 'index' and next; my $link = clone( $node );

      $link->{class}  = $node->{type} eq 'folder' ? 'folder-link' : 'file-link';
      $link->{depth} -= 2;
      $link->{tip  }  = __get_tip_text( $root, $node );

      if (defined $ids->[ 0 ] and $ids->[ 0 ] eq $node->{id}) {
         $link->{class} .= $node->{url} eq $wanted ? ' active' : ' open';
         shift @{ $ids };
      }

      push @nav, $link;
   }

   return \@nav;
}

sub build_tree {
   my ($map, $dir, $depth, $order, $url_base, $parent) = @_;

   $depth //= 0; $depth++; $order //= 0; $url_base //= NUL; $parent //= NUL;

   my $fcount = 0; my $max_mtime = 0; my $tree = {};

   for my $path ($dir->all) {
      my ($id, $pref) =  @{ make_id_from( $path->filename ) };
      my  $name       =  make_name_from( $id );
      my  $url        =  $url_base ? "${url_base}/${id}"   : $id;
      my  $header     =  $parent   ? "${parent} - ${name}" : $name;
      my  $mtime      =  $path->stat->{mtime};
      my  $node       =  $tree->{ $id } = {
          depth       => $depth,
          format      => __extension2format( $map, $path->pathname ),
          header      => $header,
          id          => $id,
          mtime       => $mtime,
          name        => $name,
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
      mtime( $node ) > $max_mtime and $max_mtime = mtime( $node );
      $fcount += $node->{fcount} = $node->{tree}->{_fcount};
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

sub extract_lang ($) {
   my $v = shift; return $v ? (split m{ _ }mx, $v)[ 0 ] : LANG;
}

sub iterator ($) {
   my $tree = shift; my @folders = ( __make_tuple( $tree ) );

   return sub {
      while (my $tuple = $folders[ 0 ]) {
         while (defined (my $k = $tuple->[ 1 ]->[ $tuple->[ 0 ]++ ])) {
            my $node = $tuple->[ 2 ]->{tree}->{ $k };

            $node->{type} eq 'folder'
               and unshift @folders, __make_tuple( $node );

            return $node;
         }

         shift @folders;
      }

      return;
   };
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

sub show_node ($;$$) {
   my ($node, $wanted, $wanted_depth) = @_;

   $wanted //= NUL; $wanted_depth //= 0;

   return $node->{depth} >= $wanted_depth
       && $node->{url  } =~ m{ \A $wanted }mx ? TRUE : FALSE;
}

# Private functions
sub __extension2format {
   my ($map, $path) = @_; my $extn = (split m{ \. }mx, $path)[ -1 ] || NUL;

   return $map->{ $extn } // 'text';
}

sub __get_tip_text {
   my ($root, $node) = @_; my $text = $node->{path}->abs2rel( $root );

   $text =~ s{ \A [a-z]+ / }{}mx; $text =~ s{ \. .+ \z }{}mx;
   $text =~ s{ [/] }{ / }gmx;     $text =~ s{ [_] }{ }gmx;

   return $text;
}

sub __make_tuple {
   my $node = shift;

   return [ 0, $node && $node->{type} eq 'folder'
               ? [ __sorted_keys( $node->{tree} ) ] : [], $node, ];
}

sub __sorted_keys {
   my $node = shift;

   return ( sort { $node->{ $a }->{_order} <=> $node->{ $b }->{_order} }
            grep { first_char $_ ne '_' } keys %{ $node } );
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
