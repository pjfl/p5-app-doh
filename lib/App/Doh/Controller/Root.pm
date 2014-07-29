package App::Doh::Controller::Root;

use Web::Simple;

with q(App::Doh::Role::Component);

has '+moniker' => default => 'root';

sub dispatch_request {
   sub (POST + /admin | /admin/*  + ?*) { [ 'admin', 'from_request', @_ ] },
   sub (GET  + /admin | /admin/*  + ?*) { [ 'admin', 'get_form',     @_ ] },
   sub (POST + /assets + *file~   + ?*) { [ 'docs',  'upload_asset', @_ ] },
   sub (GET  + /dialog            + ?*) { [ 'docs',  'get_dialog',   @_ ] },
   sub (POST + /login | /logout   + ?*) { [ 'admin', 'from_request', @_ ] },
   sub (GET  + /pod   | /pod/**   + ?*) { [ 'help',  'get_content',  @_ ] },
   sub (POST + /posts | /posts/** + ?*) { [ 'posts', 'from_request', @_ ] },
   sub (GET  + /posts | /posts/** + ?*) { [ 'posts', 'get_content',  @_ ] },
   sub (GET  + /search            + ?*) { [ 'docs',  'search_tree',  @_ ] },
   sub (POST + /user  | /user/*   + ?*) { [ 'admin', 'from_request', @_ ] },
   sub (GET  + /user  | /user/*   + ?*) { [ 'admin', 'get_dialog',   @_ ] },
   sub (POST + /      | /**       + ?*) { [ 'docs',  'from_request', @_ ] },
   sub (GET  + /      | /index    + ?*) { [ 'docs',  'get_index',    @_ ] },
   sub (GET  + /**                + ?*) { [ 'docs',  'get_content',  @_ ] };
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

=head2 C<moniker>

Returns the unique key used to store an instance of this class in a
collection of controllers. The controller's monikers are sorted and requests
are tested against each controller in turn until a match is found. The
'root' controller should probably come last

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
