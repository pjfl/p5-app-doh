requires 'CGI::Simple' => '1.113';
requires 'Class::Usul' => 'v0.25.0';
requires 'Daemon::Control' => '0.000_009';
requires 'File::DataClass' => 'v0.24.0';
requires 'HTML::Accessors' => 'v0.9.0';
requires 'Module::Pluggable' => '4.8';
requires 'Moo' => '1.003';
requires 'MooX::Options' => '3.83';
requires 'Plack' => '1.0018';
requires 'Plack::Middleware::Deflater' => '0.08';
requires 'Plack::Middleware::LogErrors' => '0.001';
requires 'Pod::Xhtml' => '1.61';
requires 'Template' => '2.22';
requires 'Text::Markdown' => '1.000031';
requires 'Web::Simple' => '0.020';
requires 'namespace::sweep' => '0.006';
requires 'perl' => '5.010001';

on 'build' => sub {
  requires 'Module::Build' => '0.4004';
  requires 'version' => '0.88';
};

on 'configure' => sub {
  requires 'Module::Build' => '0.4004';
  requires 'version' => '0.88';
};
