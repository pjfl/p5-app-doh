requires "App::Ack" => "2.12";
requires "Class::Usul" => "v0.45.0";
requires "Crypt::Eksblowfish" => "0.009";
requires "Daemon::Control" => "0.000009";
requires "Data::Validation" => "v0.15.0";
requires "Exporter::Tiny" => "0.038";
requires "File::DataClass" => "v0.44.0";
requires "HTML::Accessors" => "v0.11.0";
requires "HTTP::Body" => "1.11";
requires "HTTP::Message" => "6.06";
requires "JSON::MaybeXS" => "1.002006";
requires "Module::Pluggable" => "5.1";
requires "Moo" => "1.005000";
requires "Plack" => "1.0018";
requires "Plack::Middleware::Deflater" => "0.08";
requires "Plack::Middleware::LogErrors" => "0.001";
requires "Plack::Middleware::Session" => "0.21";
requires "Pod::Xhtml" => "1.61";
requires "Starman" => "0.3000";
requires "Template" => "2.22";
requires "Text::MultiMarkdown" => "1.000034";
requires "Try::Tiny" => "0.22";
requires "Type::Tiny" => "0.046";
requires "URI" => "1.60";
requires "Unexpected" => "v0.27.0";
requires "Web::Simple" => "0.028";
requires "YAML::Tiny" => "1.62";
requires "namespace::autoclean" => "0.19";
requires "perl" => "5.010001";
requires "strictures" => "1.005004";
requires "warnings::illegalproto" => "0.001002";
recommends "CSS::LESS" => "v0.0.3";

on 'build' => sub {
  requires "Module::Build" => "0.4004";
  requires "Test::Requires" => "0.06";
  requires "Test::Warnings" => "0.014";
  requires "version" => "0.88";
};

on 'configure' => sub {
  requires "Module::Build" => "0.4004";
  requires "Pod::Perldoc" => "3.23";
  requires "version" => "0.88";
};
