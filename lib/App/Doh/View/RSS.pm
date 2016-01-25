package App::Doh::View::RSS;

use namespace::autoclean;

use App::Doh::Util qw( stash_functions );
use Encode         qw( encode );
use English        qw( -no_match_vars );
use Moo;

with q(Web::Components::Role);
with q(Web::Components::Role::TT);

# Public attributes
has '+moniker' => default => 'rss';

# Private functions
my $_header = sub {
   return [ 'Content-Type' => 'application/rss+xml', @{ $_[ 0 ] // [] } ];
};

my $_template = do { local $RS = undef; <DATA> };

# Public methods
sub serialize {
   my ($self, $req, $stash) = @_; stash_functions $self, $req, $stash;

   $stash->{page}->{layout} = \$_template;

   my $xml = encode( $self->encoding, $self->render_template( $stash ) );

   return [ $stash->{code}, $_header->( $stash->{http_headers} ), [ $xml ] ];
}

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
 xmlns:content="http://purl.org/rss/1.0/modules/content/"
 xmlns="http://purl.org/rss/1.0/"
>
 <channel rdf:about="[% page.link %]">
  <title>[% page.title | html -%]</title>
  <link>[% page.link %]</link>
  <description>[% page.subtitle | html -%]</description>
  <language>[% page.language %]</language>
  <pubDate>[% page.pubdate %]</pubDate>
  <lastBuildDate>[% page.built %]</lastBuildDate>
  <items>
   <rdf:Seq>
[% FOREACH entry = page.entries -%]
    <rdf:li rdf:resource="[% entry.link %]"/>
[% END -%]
   </rdf:Seq>
  </items>
 </channel>
[% FOREACH entry = page.entries -%]

 <item rdf:about="[% entry.link %]">
  <title>[% entry.title | html -%]</title>
  <link>[% entry.link %]</link>
  <guid isPermaLink="false">[% entry.guid %]</guid>
  <author>[% entry.author %]</author>
[% FOREACH category = entry.categories -%]
  <category>[% category %]</category>
[% END -%]
  <content:encoded>[% entry.content | html -%]</content:encoded>
  <dc:date>[% entry.modified %]</dc:date>
 </item>
[% END -%]
</rdf:RDF>
