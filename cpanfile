requires "CGI::Simple" => "1.113";
requires "Class::Usul" => "v0.39.0";
requires "Daemon::Control" => "0.000009";
requires "File::DataClass" => "v0.33.0";
requires "HTML::Accessors" => "v0.11.0";
requires "Module::Pluggable" => "4.8";
requires "Moo" => "1.003";
requires "Plack" => "1.0018";
requires "Plack::Middleware::Deflater" => "0.08";
requires "Plack::Middleware::LogErrors" => "0.001";
requires "Pod::Xhtml" => "1.61";
requires "Template" => "2.22";
requires "Text::Markdown" => "1.000031";
requires "Twiggy" => "0.1021";
requires "URI" => "1.60";
requires "Unexpected" => "v0.22.0";
requires "Web::Simple" => "0.020";
requires "namespace::sweep" => "0.006";
requires "perl" => "5.010001";

on 'build' => sub {
  requires "Module::Build" => "0.4004";
  requires "version" => "0.88";
};

on 'configure' => sub {
  requires "Module::Build" => "0.4004";
  requires "version" => "0.88";
};
