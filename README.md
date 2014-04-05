# Name

App::Doh - An easy way to document a project using Markdown

# Synopsis

    # Start the server in the background
    bin/doh-daemon start

    # Stop the background server
    bin/doh-daemon stop

    # Options help
    bin/doh-daemon -?

# Version

This documents version v0.1.$Rev: 36 $ of [App::Doh](https://metacpan.org/pod/App::Doh)

# Description

A simple microformat document server written in Perl utilising [Plack](https://metacpan.org/pod/Plack)
and [Web::Simple](https://metacpan.org/pod/Web::Simple)

# Configuration and Environment

The configuration file attributes are documented in the [App::Doh::Config](https://metacpan.org/pod/App::Doh::Config)
package

# Subroutines/Methods

None

# Diagnostics

Starting the daemon with the `-D` option will cause it to print debug
information to the log file `var/logs/daemon.log`

The development server can be started using

    plackup bin/doh-server

# Dependencies

- [Class::Usul](https://metacpan.org/pod/Class::Usul)
- [Moo](https://metacpan.org/pod/Moo)

# Incompatibilities

There are no known incompatibilities in this module

# Bugs and Limitations

There are no known bugs in this module.
Please report problems to the address below.
Patches are welcome

# Acknowledgements

- Larry Wall

    For the Perl programming language

- Justin Walsh

    For https://github.com/justinwalsh/daux.io from which [App::Doh](https://metacpan.org/pod/App::Doh) was forked

# Author

Peter Flanigan, `<pjfl@cpan.org>`

# License and Copyright

Copyright (c) 2014 Peter Flanigan. All rights reserved

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. See [perlartistic](https://metacpan.org/pod/perlartistic)

This program is distributed in the hope that it will be useful,
but WITHOUT WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE
