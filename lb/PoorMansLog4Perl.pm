package PoorMansLog4Perl;

use strict;
use Carp qw(carp confess);

use base qw(Exporter); our @EXPORT=qw(WARN LOGDIE);

sub _timestamp {
  my @args = @_;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime();
  return sprintf("%d/%d/%d %d:%d:%d %s",
                  $year + 1900, $mon, $mday,
                  $hour, $min, $sec,
                 join("", @args));
}

sub WARN ($) {
  carp _timestamp(@_);
}

sub LOGDIE ($) {
  confess _timestamp(@_);
}
