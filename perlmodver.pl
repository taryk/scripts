#!/usr/bin/perl

use strict;
use warnings;

foreach my $module ( @ARGV ) {
  eval "require $module";
  printf( "%-20s: %s\n", $module, $module->VERSION ) unless $@;
}
