**Doh** is a documentation generator that uses a simple folder
  structure and Markdown files to create custom documentation on the
  fly. It helps you create great looking documentation in a developer
  friendly way.

## Features

* 100% Mobile responsive
* Supports GitHub flavored narkdown
* Automatically created home / landing page
* Automatic syntax highlighting
* Automatically generated navigation
* 4 Built-in colour themes or roll your own
* Functional, flat design style
* Shareable / linkable SEO friendly URLs
* Bootstrap classes on the markup
* No build step
* Git / SVN friendly
* Google analytics
* Optional code float layout

## Acknowledgements

I saw [Daux.io](https://github.com/justinwalsh/daux.io) on Github and it
said "Fork Me" so I did. I also exchanged the PHP for Perl. Not a fan of
Bootstrap so that went also.

## Installation

The App-Doh repository contains meta data that lists the CPAN modules
used by the application. Modern Perl CPAN distribution installers
(like [App::cpanminus](https://metacpan.org/module/App::cpanminus))
use this information to install the required dependencies when this
application is installed.

**Requirements:**

* Perl 5.10.1 or above

If you don't already have it, bootstrap
[App::cpanminus](https://metacpan.org/module/App::cpanminus) with:

   curl -L http://cpanmin.us | perl - --sudo App::cpanminus

Then install [local::lib](https://metacpan.org/module/local::lib) with:

   cpanm --local-lib=~/perl5 local::lib && \
      eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)

Install **App-Doh** with:

   cpanm git://github.com/pjfl/p5-app-doh.git Doh

By default the server will run at: <a href="http://localhost:5000"
target="_blank">http://localhost:5000</a> and can be started
in the foreground with:

   plackup bin/doh-server

To start in the background listening by default on port 8085 use:

   bin/doh-daemon start

The doh-daemon program provides normal SysV init script semantics. Additionally
the daemon program will write an init script to standard output in response
to the command:

   bin/doh-daemon get_init_file

## Folders

The generator will look for folders in the `/docs` folder. Add your
folders inside the `/docs` folder. This project contains some example
folders and files to get you started.

You can nest folders any number of levels to get the exact structure
you want. The folder structure will be converted to the nested
navigation.

## Files

The generator will look for Markdown `*.md` or `*.mkdn` files inside
the `/docs` folder and any of the subfolders within `/docs`.

You must use either the `.md` or the `.mkdn` file extension for your
files. Also, you must use underscores instead of spaces. Here are some
example file names and what they will be converted to:

**Good:**

* 01_Getting_Started.md = Getting Started
* API_Calls.md = API Calls
* 200_Something_Else-Cool.md = Something Else-Cool

**Bad:**

* File Name With Space.md = FAIL

The generator will also look for files with the extensions; `.pl`, `.pm`, and
`.pod`. It will create markup from Perl's POD contained in these files.

Text files with `.txt` extension will be rendered wrapped in 'pre' tags.

## Sorting

To sort your files and folders in a specific way, you can prefix them
with a number and underscore, e.g. `/docs/01_Hello_World.md` and
`/docs/05_Features.md` This will list *Hello World* before *Features*,
overriding the deafult alpha-numeric sorting. The numbers will be
stripped out of the navigation and urls.

## Landing page

If you want to create a beautiful landing page for your project,
simply create a `index.md` file in the root of the `/docs`
folder. This file will then be used to create a landing page. You can
also add a description and image to this page using the config file like
this:

   {
      "title": "Doh!",
      "description": "An Easiest Way To Document Your Project",
      "brand": "app.png"
   }

## Configuration

To customize the look and feel of your documentation, you can create a
`doh.json` file in the of the `/docs` folder. The `doh.json`
file is a simple JSON object that you can use to change some of the
basic settings of the documentation.

###Title:
Change the title bar in the docs

   {
      "title": "Doh!"
   }

###Themes:
We have 4 built-in colour themes. To use one of the themes, just
set the `theme` option to one of the following:

* blue
* green
* navy
* red

You can set the theme option by appending '?theme=&lt;colour&gt;' to any URI.
The value will persist once it has been set.

   {
      "theme": "blue"
   }

###Custom Theme:
To create a custom color scheme, set the `theme` property to `custom`
and then define the required colors. Copy the following configuration
to get started:

   {
      "theme": "custom",
      "colors": {
         "sidebar-background": "#f7f7f7",
         "sidebar-hover": "#c5c5cb",
         "lines": "#e7e7e9",
         "dark": "#3f4657",
         "light": "#82becd",
         "text": "#2d2d2d",
         "syntax-string": "#022e99",
         "syntax-comment": "#84989b",
         "syntax-number": "#2f9b92",
         "syntax-label": "#840d7a"
      }
   }

###Code Floating:
By deafult your code blocks will be floated to a column on the right
side of your content. To disable this feature, set the `float`
property to `false`, or add `?float=0` to any URI to store the choice
in the preferences. Add `?float=float-view` to any URI to re-enable the
feature

   {
      "float": false
   }


###Github Repo:
Add a 'Fork me on Github' ribbon.

   {
      "repo_url": "https://github.com/pjfl/p5-app-doh.git"
   }

###Twitter:
Include twitter follow buttons in the sidebar.

   {
      "twitter": [ "perl", "web-simple" ]
   }

###Links:
Include custom links in the sidebar.

   {
      "links": {
         "Download": "https://github.com/pjfl/p5-app-doh/archive/master.zip",
         "Github Repo": "https://github.com/pjfl/p5-app-doh.git",
         "Issues/Wishlist": "http://github.com/pjfl/p5-app-doh/issues"
      }
   }

###Google Analytics:
This will embed the google analytics tracking code.

   {
      "google_analytics": "UA-XXXXXXXXX-XX"
   }

## Support

If you need help using Doh, or have found a bug, please create an
issue on the <a href="https://github.com/pjfl/p5-app-doh/issues"
target="_blank">Github repo</a>.
