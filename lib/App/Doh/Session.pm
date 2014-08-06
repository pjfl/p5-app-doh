package App::Doh::Session;

use namespace::autoclean;

use Moo;
use Class::Usul::Constants qw( FALSE NUL TRUE );
use Class::Usul::Functions qw( bson64id );
use Class::Usul::Types     qw( BaseType Bool HashRef NonEmptySimpleStr
                               NonZeroPositiveInt SimpleStr Undef );
use Type::Utils            qw( enum );

my $BLOCK_MODES = enum 'Block_Modes' => [ 1, 2, 3 ];

has 'authenticated' => is => 'rw',  isa => Bool, default => FALSE;

has 'code_blocks'   => is => 'rw',  isa => $BLOCK_MODES, default => 1;

has 'float'         => is => 'rw',  isa => Bool, default => TRUE;

has 'messages'      => is => 'ro',  isa => HashRef, default => sub { {} };

has 'query'         => is => 'rw',  isa => SimpleStr | Undef;

has 'skin'          => is => 'rw',  isa => NonEmptySimpleStr,
   default          => 'default';

has 'theme'         => is => 'rw',  isa => NonEmptySimpleStr,
   default          => 'green';

has 'updated'       => is => 'ro',  isa => NonZeroPositiveInt, required => TRUE;

has 'use_flags'     => is => 'rw',  isa => Bool, default => TRUE;

has 'username'      => is => 'rw',  isa => SimpleStr, default => NUL;

has 'usul'          => is => 'ro',  isa => BaseType,
   handles          => [ 'config', 'log' ],
   init_arg         => 'builder',   required => TRUE;

has '_mid'          => is => 'rwp', isa => NonEmptySimpleStr | Undef;

has '_session'      => is => 'ro',  isa => HashRef, required => TRUE;

around 'BUILDARGS' => sub {
   my ($orig, $self, @args) = @_; my $attr = $orig->( $self, @args );

   my $env = delete $attr->{env}; $attr->{_session} = $env->{ 'psgix.session' };

   for my $k (keys %{ $attr->{_session} }) {
      $attr->{ $k } = $attr->{_session}->{ $k };
   }

   $attr->{updated} //= time;

   return $attr;
};

sub BUILD {
   my $self = shift; my $max_time = $self->config->max_session_time;

   if ($self->authenticated and $max_time
       and time > $self->updated + $max_time) {
      my $username = $self->username; $self->authenticated( FALSE );
      my $message  = 'User [_1] session expired';

      $self->_set__mid( $self->status_message( [ $message, $username ] ) );
   }

   return;
}

sub clear_status_message {
   my ($self, $req) = @_; my ($mid, $msg);

   $mid = $req->query_params->( 'mid', { optional => TRUE } )
      and $msg = delete $self->messages->{ $mid }
      and return $req->loc( @{ $msg } );

   $mid = $self->_mid
      and $msg = delete $self->messages->{ $mid }
      and $self->log->debug( $req->loc_default( @{ $msg } ) );

   return $msg ? $req->loc( @{ $msg } ) : NUL;
}

sub status_message {
   my $mid = bson64id; $_[ 0 ]->messages->{ $mid } = $_[ 1 ]; return $mid;
}

sub update {
   my $self = shift; my @attrs = qw( authenticated messages username );

   my @messages = sort keys %{ $self->messages };

   while (@messages > $self->config->max_messages) {
      my $mid = shift @messages; delete $self->messages->{ $mid };
   }

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
