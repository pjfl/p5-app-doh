package App::Doh::Attributes;

use strictures;
use namespace::autoclean ();
use parent 'Exporter::Tiny';

our @EXPORT = qw( FETCH_CODE_ATTRIBUTES MODIFY_CODE_ATTRIBUTES );

my $Code_Attr = {};

sub import {
   my $class   = shift;
   my $caller  = caller;
   my $globals = { $_[ 0 ] && ref $_[ 0 ] eq 'HASH' ? %{+ shift } : () };

   namespace::autoclean->import( -cleanee => $caller, -except => [ @EXPORT ] );
   $globals->{into} //= $caller; $class->SUPER::import( $globals );
   return;
}

sub FETCH_CODE_ATTRIBUTES {
   my ($class, $code) = @_; return $Code_Attr->{ 0 + $code } // {};
}

sub MODIFY_CODE_ATTRIBUTES {
   my ($class, $code, @attrs) = @_;

   for my $attr (@attrs) {
      my ($k, $v) = $attr =~ m{ \A ([^\(]+) (?: [\(] ([^\)]+) [\)] )? \z }mx;

      my $vals = $Code_Attr->{ 0 + $code }->{ $k } //= []; defined $v or next;

         $v =~ s{ \A \` (.*) \` \z }{$1}msx
      or $v =~ s{ \A \" (.*) \" \z }{$1}msx
      or $v =~ s{ \A \' (.*) \' \z }{$1}msx; push @{ $vals }, $v;

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
