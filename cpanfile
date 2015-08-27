requires "App::Ack" => "2.12";
requires "Class::Usul" => "v0.63.0";
requires "Cpanel::JSON::XS" => "3.0115";
requires "Crypt::Eksblowfish" => "0.009";
requires "Daemon::Control" => "0.001006";
requires "Data::Validation" => "v0.21.0";
requires "Exporter::Tiny" => "0.042";
requires "File::DataClass" => "v0.65.0";
requires "HTML::Accessors" => "v0.13.0";
requires "HTML::GenerateUtil" => "1.20";
requires "HTTP::Body" => "1.19";
requires "HTTP::Message" => "6.06";
requires "JSON::MaybeXS" => "1.003005";
requires "Moo" => "2.000001";
requires "Plack" => "1.0032";
requires "Plack::Middleware::Debug" => "0.16";
requires "Plack::Middleware::Deflater" => "0.08";
requires "Plack::Middleware::FixMissingBodyInRedirect" => "0.12";
requires "Plack::Middleware::LogErrors" => "0.001";
requires "Plack::Middleware::Session" => "0.21";
requires "Pod::Xhtml" => "1.61";
requires "Starman" => "0.3000";
requires "Template" => "2.26";
requires "Text::MultiMarkdown" => "1.000034";
requires "Try::Tiny" => "0.22";
requires "Type::Tiny" => "1.000004";
requires "Unexpected" => "v0.38.0";
requires "Web::Simple" => "0.030";
requires "YAML::Tiny" => "1.67";
requires "local::lib" => "2.000014";
requires "namespace::autoclean" => "0.26";
requires "namespace::clean" => "0.25";
requires "perl" => "5.010001";
requires "strictures" => "2.000000";
requires "warnings::illegalproto" => "0.001002";
recommends "CSS::LESS" => "v0.0.3";

on 'build' => sub {
  requires "Module::Build" => "0.4004";
  requires "Test::Requires" => "0.06";
  requires "Test::Warnings" => "0.014";
  requires "version" => "0.88";
};

on 'test' => sub {
  requires "File::Spec" => "0";
  requires "Module::Metadata" => "0";
  requires "Sys::Hostname" => "0";
};

on 'test' => sub {
  recommends "CPAN::Meta" => "2.120900";
};

on 'configure' => sub {
  requires "Module::Build" => "0.4004";
  requires "Pod::Perldoc" => "3.23";
  requires "version" => "0.88";
};
