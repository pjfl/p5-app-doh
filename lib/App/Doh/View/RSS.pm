package App::Doh::View::RSS;

use namespace::autoclean;

use App::Doh::Util         qw( stash_functions );
use Class::Usul::Constants qw( NUL );
use Class::Usul::Types     qw( HashRef Object );
use Encode                 qw( encode );
use English                qw( -no_match_vars );
use Moo;

with q(Web::Components::Role);
with q(Web::Components::Role::TT);

# Public attributes
has '+moniker' => default => 'rss';

has 'formatters' => is => 'lazy', isa => HashRef[Object],
   builder       => sub { $_[ 0 ]->components->{html}->formatters };

# Private functions
my $_header = sub {
   return [ 'Content-Type' => 'application/rss+xml', @{ $_[ 0 ] // [] } ];
};

my $_template = do { local $RS = undef; <DATA> };

# Private methods
my $_filter = sub {
   my ($self, $src) = @_; my $max_chars = 1000; my $max_lines = 10;

   my @lines = split m{ \n }mx, $src, $max_lines + 1;

   @lines > $max_lines and pop @lines;

   return (substr join( "\n", @lines), 0, $max_chars - 3).'...';
};

my $_format = sub {
   my ($self, $req, $entry) = @_;

   my $content = $entry->{content}; my $formatter;

   $entry->{format} and $formatter = $self->formatters->{ $entry->{format} };

   $formatter and $entry->{filter} = $_filter
              and $content = $formatter->serialize( $req, $entry );

   return { content => $content,
            date    => $entry->{date},
            link    => $req->uri_for( $entry->{url} ),
            title   => $req->loc( $entry->{title} ), };
};

# Public methods
sub serialize {
   my ($self, $req, $stash) = @_; stash_functions $self, $req, $stash;

   $stash->{page}->{layout} = \$_template;

   my $xml = encode( $self->encoding, $self->render_template( $stash ) );

   return [ $stash->{code}, $_header->( $stash->{http_headers} ), [ $xml ] ];
}

# Construction
around 'serialize' => sub {
   my ($orig, $self, $req, $stash) = @_; my $page = $stash->{page};

   $page->{entries}
      = [ map { $_format->( $self, $req, $_ ) } @{ $page->{entries} } ];

   return $orig->( $self, $req, $stash );
};

1;

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:

__DATA__
<?xml version="1.0"?>
<rdf:RDF
 xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
 xmlns:dc="http://purl.org/dc/elements/1.1/"
 xmlns:foaf="http://xmlns.com/foaf/0.1/"
 xmlns:content="http://purl.org/rss/1.0/modules/content/"
 xmlns="http://purl.org/rss/1.0/"
>
<channel rdf:about="[% page.link -%]">
<title>[% page.title | html -%]</title>
<link>[% page.link -%]</link>
<description>[% page.subtitle | html -%]</description>
<items>
 <rdf:Seq>
[% FOREACH entry = page.entries -%]
  <rdf:li rdf:resource="[% entry.link -%]"/>
[% END -%]
 </rdf:Seq>
</items>
</channel>

[% FOREACH entry = page.entries -%]
<item rdf:about="[% entry.link -%]">
<title>[% entry.title | html -%]</title>
<link>[% entry.link -%]</link>
<content:encoded>[% entry.content | html -%]</content:encoded>
<dc:date>[% time2str( '%Y-%m-%dT%XZ', entry.date ) -%]</dc:date>
</item>
[% END -%]
</rdf:RDF>
