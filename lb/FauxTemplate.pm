package FauxTemplate; use strict; use warnings;

# Poor man's Template Toolkit, in 30 lines or less.

use base qw(Exporter); our @EXPORT = our @EXPORT_OK = qw(interpolate);

sub tmpl2code { join("", map {
  s/\[%\s+(\S+)\s+%\]/directive($1, $_)/ge;
  our $inperl ? $_                                                      :
        m/\S/ ? do { chomp; s/\|/\|/g; qq{\$_out .= q|$_| . "\\n";\n} } : "";
} @_) }

sub interpolate {
  our $_out = "";
  eval tmpl2code(@_); die $@ if $@;
  return $_out;
}

sub directive {
  my ($kw, $line) = @_;
  my %actions = (
    PERL => sub { our $inperl = 1; return "" },
    END  => sub { our $inperl = 0; return "" }
  );
  if (my $action = $actions{$kw}) { return $action->($line); }
  # Yeah, yeah, I know, TT #doesnotworkthatway...
  $kw =~ s/\./->/g; "| . \$$kw . q|";
}
