package App::Doh::CLI;

use namespace::sweep;

use Moo;
use App::Doh::Model::Documentation;
use Class::Usul::Constants;
use Class::Usul::Functions qw( throw );
use Class::Usul::Types     qw( Object );
use File::DataClass::IO;

extends q(Class::Usul::Programs);

# Override default in base class
has '+config_class' => default => 'App::Doh::Config';

has 'model' => is => 'lazy', isa => Object, builder => sub {
   App::Doh::Model::Documentation->new( builder => $_[ 0 ] );
};

sub make_static : method {
   my $self = shift; my $dest = io( $self->next_argv // 'static' );

   $dest->is_absolute or $dest = io( $dest->rel2abs( $self->config->root ) );
   $self->_copy_assets( $dest );

   for my $locale (keys %{ $self->model->docs_tree }) {
      $self->_make_static( $dest, $locale );
   }

   return OK;
}

sub _copy_assets {
   my ($self, $dest) = @_; my $conf = $self->config; my $root = $conf->root;

   $dest->exists or $dest->mkpath; $dest->rmtree( { keep_root => TRUE } );

   my ($unwanted_images, $unwanted_js, $unwanted_less);

   if ($conf->colours->[ 0 ]) {
      $unwanted_images = qr{ favicon \- (?: blue|green|navy|red ) }mx;
      $unwanted_less   = qr{ theme   \- (?: blue|green|navy|red ) }mx;

      __deep_copy( $root->catdir( $conf->less ), $dest, $unwanted_less );
   }
   else {
      $unwanted_images = qr{ favicon\.png  }mx;
      $unwanted_js     = qr{ less\.min\.js }mx;

      __deep_copy( $root->catdir( $conf->css ), $dest );
   }

   __deep_copy( $root->catdir( $conf->images ), $dest, $unwanted_images );
   __deep_copy( $root->catdir( $conf->js     ), $dest, $unwanted_js     );
   return;
}

sub _make_static {
   my ($self, $dest, $locale) = @_;

   my $iter = $self->model->iterator( $locale );

   while (my $node = $iter->()) {
      $node->{type} ne 'file' and next;

      my $url     =  '/'.$node->{url}."?locale=${locale}";
      my $cmd     =  [ $self->config->binsdir->catfile( 'doh-server' ), $url ];
      my $content =  $self->run_cmd( $cmd )->out;
      my $path    =  io( $node->{path} )->abs2rel( $self->config->file_root );
         $path    =~ s{ \. (.+) \z }{\.html}mx;

      io( [ $dest, $path ] )->assert_filepath->print( $content );
   }

   return;
}

sub __deep_copy {
   my ($src, $dest, $excluding) = @_; $excluding //= qr{ NUL() }mx;

   my $filter = sub { $_->is_file && $_ !~ $excluding };
   my $iter   = $src->deep->filter( $filter )->iterator;

   while (my $from = $iter->()) {
      my $to = $dest->catfile( $from->abs2rel( $src->parent ) );

      $from->copy( $to->assert_filepath );
   }

   return;
}

1;

__END__

=pod

=encoding utf8

=head1 Name

App::Doh::CLI - One-line description of the modules purpose

=head1 Synopsis

   use App::Doh::CLI;
   # Brief but working code examples

=head1 Description

=head1 Configuration and Environment

Defines the following attributes;

=over 3

=back

=head1 Subroutines/Methods

=head2 make_static - Make a static HTML copy of the documentation

=head1 Diagnostics

=head1 Dependencies

=over 3

=item L<Class::Usul>

=back

=head1 Incompatibilities

There are no known incompatibilities in this module

=head1 Bugs and Limitations

There are no known bugs in this module. Please report problems to
http://rt.cpan.org/NoAuth/Bugs.html?Dist=App-Doh.
Patches are welcome

=head1 Acknowledgements

Larry Wall - For the Perl programming language

=head1 Author

Peter Flanigan, C<< <pjfl@cpan.org> >>

=head1 License and Copyright

Copyright (c) 2014 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See L<perlartistic>

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE

=cut

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
