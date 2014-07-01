package App::Doh::Controller::Root;

use Web::Simple;

sub dispatch_request {
   sub (POST + /assets + *file~ + ?*) {
      return shift->execute( qw( html docs  upload_asset ), @_ );
   },
   sub (GET  + /dialog + ?*) {
      return shift->execute( qw( xml  docs  get_dialog ), @_ );
   },
   sub (POST + /login | /logout + ?*) {
      return shift->execute( qw( html auth  from_request ), @_ );
   },
   sub (GET  + /login + ?*) {
      return shift->execute( qw( xml  auth  get_dialog ), @_ );
   },
   sub (GET  + /pod | /pod/** + ?*) {
      return shift->execute( qw( html help  get_content ), @_ );
   },
   sub (POST + /posts | /posts/** + ?*) {
      return shift->execute( qw( html posts from_request ), @_ );
   },
   sub (GET  + /posts | /posts/** + ?*) {
      return shift->execute( qw( html posts get_content ), @_ );
   },
   sub (GET  + /search + ?*) {
      return shift->execute( qw( html docs  search_tree ), @_ );
   },
   sub (POST + / | /** + ?*) {
      return shift->execute( qw( html docs  from_request ), @_ );
   },
   sub (GET  + / | /index + ?*) {
      return shift->execute( qw( html docs  get_index ), @_ );
   },
   sub (GET  + /** + ?*) {
      return shift->execute( qw( html docs  get_content ), @_ );
   };
}

1;

__END__

=pod

=encoding utf-8

=head1 Name

App::Doh::Controller::Root - Maps URIs onto view and model methods calls

=head1 Synopsis

   use App::Doh::Controller::Root;
   use Class::Usul::Types qw( ArrayRef Object );
   use Web::Simple;

   has '_controllers' => is => 'lazy', isa => ArrayRef[Object],
      reader => 'controllers', builder => sub { [
         App::Doh::Controller::Root->new,
      ] };

   sub dispatch_request {
      return map { $_->dispatch_request } @{ $_[ 0 ]->controllers };
   }

=head1 Description

Maps URIs onto model methods calls

=head1 Configuration and Environment

Defines no attributes

=head1 Subroutines/Methods

=head2 C<dispatch_request>

Returns a list of code references. The prototype for each anonymous
subroutine matches against a specific URI pattern. It the request URI
matches this pattern the subroutine is called. Each subroutine calls
the L<execute|App::Doh::Server/execute> method

=head1 Diagnostics

None

=head1 Dependencies

=over 3

=item L<Web::Simple>

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
