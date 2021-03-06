[![Build Status](https://api.travis-ci.org/pjfl/p5-app-doh.svg?branch=master)](https://travis-ci.org/pjfl/p5-app-doh)


**Doh** is a documentation generator that uses a simple folder structure and
[Markdown](http://daringfireball.net/projects/markdown/) files to create
custom documentation on the fly. It helps you create great looking
documentation in a developer friendly way.

## Features

* 100% Mobile responsive
* Supports an extended flavour of multi-markdown
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
* CodeMirror markdown editor and file management
* Multi-language support
* Static site generator
* Text searching

## Acknowledgements

I saw [Daux.io](https://github.com/justinwalsh/daux.io) on Github and it said
"Fork Me" so I did.

JavaScript libraries hosted by [CloudFlare](https://www.cloudflare.com/).

## Differences

I exchanged the PHP for modern [Perl](http://www.perl.org),
[Moo](https://metacpan.org/module/Moo),
[Plack](https://metacpan.org/module/Plack), and
[Web::Simple](https://metacpan.org/module/Web::Simple). Not a fan of Bootstrap
so that went also. Prefer class based inheritance when JavaScript programming
hence [Mootools](http://mootools.net/) not jQuery.

## Installation

The [App-Doh repository](http://github.com/pjfl/p5-app-doh) contains meta data
that lists the CPAN modules used by the application. Modern Perl CPAN
distribution installers (like
[App::cpanminus](https://metacpan.org/module/App::cpanminus)) use this
information to install the required dependencies when this application is
installed.

**Requirements:**

* Perl 5.12.0 or above
* Git - to install **App::Doh** from Github

To find out if Perl is installed and which version; at a shell prompt type

```shell
   perl -v
```
To find out if Git is installed, type

```shell
   git --version
```

If you don't already have it, bootstrap
[App::cpanminus](https://metacpan.org/module/App::cpanminus) with:

```shell
   curl -L http://cpanmin.us | perl - --sudo App::cpanminus
```

Then install [local::lib](https://metacpan.org/module/local::lib) with:

```shell
   cpanm --notest --local-lib=~/App-Doh local::lib && \
      eval $(perl -I ~/App-Doh/lib/perl5/ -Mlocal::lib=~/App-Doh)
```

The second statement sets environment variables to include the local Perl
library. You can append the output of the perl command to your shell startup if
you want to make it permanent. Without the correct environment settings Perl
will not be able to find the installed dependencies and the following will
fail, badly.

Install **App-Doh** with:

```shell
   cpanm --notest git://github.com/pjfl/p5-app-doh.git
```

Although this is a *simple* application it is composed of many CPAN
distributions and, depending on how many of them are already available,
installation may take a while to complete. The flip side is that there are no
external dependencies like Node.js or Grunt to install. Anyway you are advised
to seek out sustenance whilst you wait for ack-2.12 to run it's tests.  At the
risk of installing broken modules (they are only going into a local library)
you can skip the tests by running `cpanm` with the `--notest` option.

If that fails run it again with the --force option

```shell
   cpanm --force git:...
```

By default the development server will run at:
[http://localhost:5000](http://localhost:5000) and can be started in the
foreground with:

```shell
   cd App-Doh
   plackup bin/doh-server
```

Users must authenticate against the `users.json` file under the document
root. The default user is `admin` password `admin123`. You should change that
via the user profile editor which is the stud that appears on the right of the
header after you have logged in. To start the production server in the
background listening on the default port 8085 use:

```shell
   doh-daemon start
```

The `doh-daemon` program provides normal SysV init script semantics.
Additionally the daemon program will write an init script to standard output in
response to the command:

```shell
   doh-daemon get_init_file
```

## Folders

The generator will look for folders in the `var/root/docs` folder. Add your
folders inside the `var/root/docs` folder. This project contains some example
folders and files to get you started.

The first folder under `var/root/docs` should be a language code. This defaults
to `en` for English. Even if you only plan to use one language you will still
need to create your files and folders underneath the language folder.

You can nest folders any number of levels to get the exact structure you want.
The folder structure will be converted to the nested navigation.

## Files

The generator will look for Markdown `*.md` or `*.mkdn` files inside
the `var/root/docs` folder and any of the subfolders within `var/root/docs`.

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

To sort your files and folders in a specific way, you can prefix them with a
number and underscore, e.g. `var/root/docs/en/01_Hello_World.md` and
`var/root/docs/en/05_Features.md`. This will list *Hello World* before
*Features*, overriding the deafult alpha-numeric sorting. The language code,
numbers, and file extensions will be stripped out of the navigation links and
URIs.

## Landing page

If you want to create a beautiful landing page for your project,
simply create a `index.md` file in the root of the `var/root/docs/en`
folder. This file will then be used to create a landing page. You can
also add a description and image to this page using the config file like
this:

```json
   {
      "title": "Doh!",
      "description": "An Easiest Way To Document Your Project",
      "brand": "app.png"
   }
```

## Configuration

To customize the look and feel of your documentation, you can create a
`app-doh.json` file in the of the `var/root/docs` folder. The `app-doh.json`
file is a simple JSON object that you can use to change some of the
basic settings of the documentation. The
[config help](/help/App::Doh::Config) page details the available
configuration attributes

### Title:
Change the title bar in the docs

```json
   {
      "title": "Doh!"
   }
```

### Themes:
We have 4 built-in colour themes. To use one of the themes, just
set the `theme` option to one of the following:

* blue
* green
* navy
* red

You can set the theme option by appending '?theme=&lt;colour&gt;' to any URI.
The value will persist once it has been set.

```json
   {
      "theme": "blue"
   }
```

### Custom Theme:
To create a custom color scheme, set the `theme` property to `custom`
and then define the required colors. Copy the following configuration
to get started:

```json
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
```

### Code Floating:
By deafult your code blocks will be floated to a column on the right
side of your content. To disable this feature, set the `float`
property to `false`, or add `?float=0` to any URI to store the choice
in the preferences. Add `?float=1` to any URI to re-enable the
feature

```json
   {
      "float": false
   }
```

### Ignore:
The config attribute `no_index` is a list of filename patterns to ignore
when indexing the document tree

```json
   [ '.git', '.htpasswd', '.svn', 'app-doh.json' ]
```

### Locales:
The list of locales (languages) supported

```json
   {
      "locales": [ "en", "de" ]
   }
```

### Github Repo:
Add a 'Fork me on Github' ribbon.

```json
   {
      "repo_url": "https://github.com/pjfl/p5-app-doh.git"
   }
```

### Twitter:
Include twitter follow buttons in the sidebar.

```json
   {
      "twitter": [ "perl", "web-simple" ]
   }
```

### Links:
Include custom links in the sidebar.

```json
   {
      "links": {
         "Download": "https://github.com/pjfl/p5-app-doh/archive/master.zip",
         "Github Repo": "https://github.com/pjfl/p5-app-doh.git",
         "Issues/Wishlist": "http://github.com/pjfl/p5-app-doh/issues"
      }
   }
```

### Google Analytics:
This will embed the Google Analytics tracking code.

```json
   {
      "analytics": "UA-XXXXXXXXX-XX"
   }
```

## Toggling Code Blocks
The select menu in the left column of the documentation template allows
for the selection of different code block display modes. Code blocks
can be displayed in the page float view, the can be displayed inline, and
they can be hidden

## Multi-language Support

Use your browsers preferences to set the `Accept-Language` header in the
request to the desired language. If available it will be served in preference
to the default language, English.

The national flag on the right of the title bar indicates the language of the
file being displayed or edited. Adding `?use_flags=0` to a URI will turn the
flags off and display a language code instead.

Text within the application can be translated into other languages by
creating GNU Gettext portable object files. The path is
`var/locale/<language_code>/LC_MESSAGES` and the two file names are
`default.po` and `app_doh.po`. Messages in the `default.po` are common to all
programs in the application. Creating English translation files allows the
terse error messages to be replaced with more user friendly ones.

### Directory structure:

```
   ├── docs/
   │   ├── en/
   │   │   ├── index.md
   │   │   ├── 00_Getting_Started.md
   │   │   ├── 01_Examples/
   │   │   │   ├── 01_GitHub_Flavored_Markdown.md
   │   │   │   ├── 05_Code_Highlighting.md
   │   │   ├── 05_More_Examples/
   │   │   │   ├── Hello_World.md
   │   │   │   ├── 05_Code_Highlighting.md
   │   ├── de/
   │   │   ├── index.md
   │   │   ├── 00_Getting_Started.md
   │   │   ├── 01_Examples/
   │   │   │   ├── 01_GitHub_Flavored_Markdown.md
   │   │   │   ├── 05_Code_Highlighting.md
   │   │   ├── 05_More_Examples/
   │   │   │   ├── Hello_World.md
   │   │   │   ├── 05_Code_Highlighting.md
```

## Markdown Editor
<img alt="[File editor]" class="app-thumbnail"
     src="[% links.images %]app-editor.png"/>

The markdown in the document tree is editable via the web browser. The
`Edit` link is in the left navigation column after the code blocks
selector. The `Save` button at the bottom of the text editor makes the
changes permanent.

The `Create` link displays a modal dialog. Enter the path to the file you want
to create. The path should be relative to the language sub-directory, it
should not begin with a leading slash. Do include numeric prefixes for sorting
purposes, use slashes to delineate directories and files, spaces will be
replaced with underscores, and the file extension is optional. Any new
directories in the file path will be automatically created.

The `Delete` link will prompt for confirmation before deleting the markdown
file. Empty directories will be removed.

The `Upload` link lets you select a file to upload. The uploaded file appears
in the `var/root/docs/assets` directory. It can be referenced from a template
using `[\% links.assets %\]your-asset.jpg`, or from markdown as
`[\%links.assets%\]your-asset.jpg` (no spaces).

## Generating CSS from Less

Only the green theme is precompiled, if you want the other colour themes then
install Node, Lessc, and CSS::LESS. As root:

```shell
   apt-get update
   apt-get install git-core curl build-essential openssl libssl-dev
   git clone https://github.com/joyent/node.git
   cd node
   ./configure --openssl-libpath=/usr/lib/ssl
   make
   make install
   # Node installed with broken permissions which I had to fix at this point
   npm install -g less
```

Now you should have a working `lessc` command. Create the other CSS files with
(not as root):

```shell
   cpanm --force CSS::LESS
   doh-cli make_css
```

## Generating a set of static files

This command creates a static HTML version of the documentation in the
`var/root/static` directory

```shell
   doh-cli make_static
```

## Support

There is a link on the right side of the title bar that displays the Perl
documentation for [App::Doh](/help)

If you need help using Doh, or have found a bug, please create an issue on the
<a href="https://github.com/pjfl/p5-app-doh/issues" target="_blank">Github
repo</a>.

Please note that a Perl module failing to install is not an issue for *this*
application. Each Perl module has an issues tracker which can be found via that
modules [Meta::CPAN](https://metacpan.org) page
