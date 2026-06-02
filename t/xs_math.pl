use strict;
use warnings;

our $pass = 0;
our $fail = 0;
sub ok { my ($test, $name) = @_; if ($test) { $pass++; } else { $fail++; print "FAIL: $name\n"; } }

# These functions come from MyMath.xs
ok(MyMath::add(2, 3) == 5, "xs add");
ok(MyMath::add(100, 200) == 300, "xs add large");
ok(MyMath::multiply(4.0, 5.0) == 20.0, "xs multiply");
ok(MyMath::multiply(3.14, 2.0) > 6.2, "xs multiply float");
ok(MyMath::factorial(5) == 120, "xs factorial");
ok(MyMath::factorial(10) == 3628800, "xs factorial 10");

my $sqrt_val = MyMath::sqrt_val(144.0);
ok($sqrt_val == 12.0, "xs sqrt: " . $sqrt_val);

print "\nPassed: " . $pass . "\nFailed: " . $fail . "\n";
if ($fail == 0) { print "All XS tests passed!\n"; }
