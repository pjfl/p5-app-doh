package App::Doh::Attributes;

use strictures;
use namespace::autoclean ();
use parent 'Exporter::Tiny';

our @EXPORT = qw( FETCH_CODE_ATTRIBUTES MODIFY_CODE_ATTRIBUTES );

my $Code_Attr = {};

sub import {
   my $class = shift;
   my $global_opts = { $_[ 0 ] && ref $_[ 0 ] eq 'HASH' ? %{+ shift } : () };

   namespace::autoclean->import
      ( -cleanee => scalar caller, -except => [ @EXPORT ] );
   $global_opts->{into} //= caller;
   $class->SUPER::import( $global_opts );
   return;
}

sub FETCH_CODE_ATTRIBUTES {
   my ($class, $code) = @_; return $Code_Attr->{ 0 + $code } // {};
}

sub MODIFY_CODE_ATTRIBUTES {
   my ($class, $code, @attrs) = @_;

   for my $attr (@attrs) {
      my ($k, $v) = $attr =~ m{ \A ([^\(]+) (?: [\(] ([^\)]+) [\)] )? \z }mx;

      my $vals = $Code_Attr->{ 0 + $code }->{ $k } // [];

      defined $v and push @{ $vals }, $v;

      $Code_Attr->{ 0 + $code }->{ $k } = $vals;
   }

   return ();
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
