package App::Doh::Session;

use namespace::autoclean;

use Moo;
use Class::Usul::Constants qw( FALSE NUL TRUE );
use Class::Usul::Types     qw( Bool HashRef NonEmptySimpleStr
                               NonZeroPositiveInt SimpleStr Undef );
use Type::Utils            qw( enum );

extends q(App::Doh);

my $BLOCK_MODES = enum 'Block_Modes' => [ 1, 2, 3 ];

has 'authenticated'  => is => 'rw', isa => Bool, default => FALSE;

has 'code_blocks'    => is => 'rw', isa => $BLOCK_MODES, default => 1;

has 'float'          => is => 'rw', isa => Bool, default => TRUE;

has 'query'          => is => 'rw', isa => SimpleStr | Undef;

has 'skin'           => is => 'rw', isa => NonEmptySimpleStr,
   default           => 'default';

has 'status_message' => is => 'rw', isa => SimpleStr | Undef;

has 'theme'          => is => 'rw', isa => NonEmptySimpleStr,
   default           => 'green';

has 'updated'        => is => 'ro', isa => NonZeroPositiveInt, required => TRUE;

has 'use_flags'      => is => 'rw', isa => Bool, default => TRUE;

has 'username'       => is => 'rw', isa => SimpleStr, default => NUL;

has '_session'       => is => 'ro', isa => HashRef, default => sub { {} };

around 'BUILDARGS' => sub {
   my ($orig, $self, @args) = @_; my $attr = $orig->( $self, @args );

   my $env = delete $attr->{env}; $attr->{_session} = $env->{ 'psgix.session' };

   for my $k (keys %{ $attr->{_session} }) {
      $attr->{ $k } = $attr->{_session}->{ $k };
   }

   my $usul     = $attr->{builder};
   my $max_time = $usul->config->max_session_time;
   my $now      = time; $attr->{updated} //= $now;
   my $elapsed  = $now - $attr->{updated};

   if ($attr->{authenticated} and $max_time and $elapsed > $max_time) {
      my $username = $attr->{username}; $attr->{authenticated} = FALSE;

      $usul->log->debug( "User ${username} session expired" );
   }

   return $attr;
};

sub clear_status_message {
   my $self = shift; my $message = $self->status_message;

   $self->status_message( undef );
   return $message;
}

sub update {
   my $self = shift; my @attrs = qw( authenticated status_message username );

   for my $k (@{ $self->config->preferences }, @attrs) {
      $self->_session->{ $k } = $self->{ $k };
   }

   $self->_session->{updated} = time;
   return;
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
