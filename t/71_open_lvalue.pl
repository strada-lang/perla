use strict;
use warnings;

# open(EXPR, ...) where EXPR is a hash/array element (lvalue out-parameter)

# Hash element
my %fhs;
open($fhs{a}, '<', '/etc/hostname') or die "open failed: hash elem 3-arg";
my $fh = $fhs{a};
my $line = <$fh>;
chomp $line;
die "hash elem read empty" unless length($line) > 0;
close $fhs{a};

# Array element
my @arr;
open($arr[0], '<', '/etc/hostname') or die "open failed: array elem 3-arg";
my $fh2 = $arr[0];
my $line2 = <$fh2>;
chomp $line2;
die "array elem read empty" unless length($line2) > 0;
close $arr[0];

# Hash ref slot
my $href = {};
open($href->{x}, '<', '/etc/hostname') or die "open failed: arrow hash 3-arg";
my $fh3 = $href->{x};
my $line3 = <$fh3>;
chomp $line3;
die "arrow hash read empty" unless length($line3) > 0;
close $href->{x};

# Array ref slot
my $aref = [];
open($aref->[0], '<', '/etc/hostname') or die "open failed: arrow array 3-arg";
my $fh4 = $aref->[0];
my $line4 = <$fh4>;
chomp $line4;
die "arrow array read empty" unless length($line4) > 0;
close $aref->[0];

# 2-arg form, hash slot
my %fhs2;
open($fhs2{a}, '< /etc/hostname') or die "open failed: hash elem 2-arg";
my $fh5 = $fhs2{a};
my $line5 = <$fh5>;
chomp $line5;
die "2-arg hash elem read empty" unless length($line5) > 0;
close $fhs2{a};

print "ok\n";
