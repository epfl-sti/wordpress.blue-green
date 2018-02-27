#!/usr/bin/perl

use strict;
use warnings;
use v5.26;

use Docopt;
use Data::Dumper;
use IO::All;
use Tie::IxHash;
use Pod::Usage;

my $opts = docopt();

=head1 NAME

rotate-backups.pl

=head1 SYNOPSIS

  rotate-backups.pl [ -v ] [ -n | --dry-run ] <path>

=head1 FLAGS

=item -n

=item --dry-run

Do nothing, instead say what would be done.

=cut

sub is_dry_run {
  return $opts->{"-n"} || $opts->{"--dry-run"};
}

sub debug {
  if ($opts->{"-v"}) {
    say @_;
  }
}

my $dir = $opts->{'<path>'};
die "$dir: $!" unless -d($dir);

tie(our %skip_count, 'Tie::IxHash',
    86400 => 1,  # Leave one file aged between one and two days, etc.
    (86400 * 2) => 1,
    (86400 * 3) => 1,
    (86400 * 4) => 1,
    (86400 * 5) => 1,
    (86400 * 6) => 1,
    (86400 * 7) => 1,
    (86400 * 30) => 1
   );


my $now = time();
my @age_brackets = keys %skip_count;
FILE: foreach my $file
  (io("$dir/")->filter(sub { $_->filename =~ m/^backup-.*tgz$/ })
     ->sort(sub {$b->mtime <=> $a->mtime})
     ->all_files)
  {
    my $age = $now - $file->mtime;
    foreach my $i (0..$#age_brackets - 1) {
      my ($min_age, $max_age) = ($age_brackets[$i], $age_brackets[$i+1]);
      next unless ($age > $min_age && $age <= $max_age);
      if ($skip_count{$max_age}) {
        $skip_count{$max_age}--;
        debug "Sparing $file ($min_age < $age < $max_age)";
        next FILE;
      }
    }
    do_delete($file);
  }

sub do_delete {
  my ($file) = @_;
  if (is_dry_run) {
    say "Would delete $file";
  } else {
    say "Would delete $file";  # XXX Replace with actual delete
  }
}
