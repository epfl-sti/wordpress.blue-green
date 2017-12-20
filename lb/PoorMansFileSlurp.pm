package PoorMansFileSlurp;

use strict;

use base qw(Exporter); our @EXPORT=qw(read_file);

use Carp qw(confess);

sub read_file {
  my ($filename) = @_;
  local *FILE; open(FILE, "<", $filename) or confess "open($filename): $!";

  if (wantarray) {
    return <FILE>;
  } else {
    local $/;
    return <FILE>;
  }
}
