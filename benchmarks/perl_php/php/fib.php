<?php function fib($n){ if($n<=1) return $n; return fib($n-1)+fib($n-2);} $n=35; echo "fib($n) = ".fib($n)."\n";
