package App::Doh::Role::Component;

use namespace::autoclean;

use Class::Usul::Constants qw( TRUE );
use Class::Usul::Types     qw( BaseType HashRef NonEmptySimpleStr
                               NonNumericSimpleStr );
use Moo::Role;

has 'components' => is => 'ro',   isa => HashRef, default => sub { {} },
   weak_ref      => TRUE;

has 'encoding'   => is => 'lazy', isa => NonEmptySimpleStr,
   builder       => sub { $_[ 0 ]->config->encoding };

has 'moniker'    => is => 'ro',   isa => NonNumericSimpleStr, required => TRUE;

has 'usul'       => is => 'ro',   isa => BaseType,
   handles       => [ qw( config debug l10n lock log ) ],
   init_arg      => 'builder', required => TRUE;

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
