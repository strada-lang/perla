sub fib { my ($n)=@_; if ($n<=1){return $n;} return fib($n-1)+fib($n-2); }
my $n=35; print "fib($n) = " . fib($n) . "\n";
