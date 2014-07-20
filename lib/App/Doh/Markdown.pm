package App::Doh::Markdown;

use strictures;
use parent 'Text::MultiMarkdown';

sub _DoCodeBlocks { # Add support for triple graves
   my ($self, $text) = @_;

   $text =~ s{
      (?:(?:\n```(.*)\n)|\n\n|\A)
         (
           (?:
            (?:[ ]{$self->{tab_width}} | \t)
            .*\n+
            )+
           )
         (?:^```(.*)?|(?=^[ ]{0,$self->{tab_width}}\S)|\Z)
      }{
         my $class = $1 || $3 || q(); my $codeblock = $2; my $result;

         $codeblock = $self->_EncodeCode( $self->_Outdent( $codeblock ) );
         $codeblock = $self->_Detab( $codeblock );
         $codeblock =~ s/\A\n+//;
         $codeblock =~ s/\n+\z//;
         $class and $class = " class=\"${class}\"";
         $result = "\n\n<pre><code${class}>${codeblock}\n</code></pre>\n\n";
         $result;
      }egmx;

   return $text;
}

1;

__END__

# Local Variables:
# mode: perl
# tab-width: 3
# End:
# vim: expandtab shiftwidth=3:
