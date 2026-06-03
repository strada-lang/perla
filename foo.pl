use strict;
open(F, "reset-branch.sh");
my @file = <F>;
close(F);

use Data::Dumper;
warn Dumper \@file;

