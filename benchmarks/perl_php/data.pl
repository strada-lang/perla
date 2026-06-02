my $it=500000; my @a=();
for (my $i=0;$i<$it;$i++){ push(@a,$i*$i); }
my $sum=0; foreach my $v (@a){ $sum+=$v; }
my %f=();
for (my $i=0;$i<$it;$i++){ my $k="key_".($i%100); if(exists($f{$k})){$f{$k}+=1;}else{$f{$k}=1;} }
print "data: $it, sum=$sum, keys=".scalar(keys(%f))."\n";
