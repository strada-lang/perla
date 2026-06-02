my $it=1000000; my $r="";
for (my $i=0;$i<$it;$i++){ my $s="Hello, World! ".$i; $s=~s/World/Perl/; $r=$s if $i==$it-1; }
print "strings: $it, last=$r\n";
