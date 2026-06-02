use strict;
use warnings;

our $pass = 0;
our $fail = 0;
sub ok { my ($test, $name) = @_; if ($test) { $pass++; } else { $fail++; print "FAIL: $name\n"; } }

# Simple template engine: {{ var }} substitution
sub render {
    my ($template, %vars) = @_;
    my $result = $template;
    foreach my $key (keys(%vars)) {
        my $val = $vars{$key};
        my $pattern = "\\{\\{\\s*" . $key . "\\s*\\}\\}";
        $result =~ s/$pattern/$val/g;
    }
    return $result;
}

# Basic substitution
my $tpl = "Hello, {{ name }}!";
my $out = render($tpl, name => "World");
ok($out eq "Hello, World!", "basic template: " . $out);

# Multiple vars
$tpl = "{{ greeting }}, {{ name }}! You have {{ count }} items.";
$out = render($tpl, greeting => "Hi", name => "Alice", count => "5");
ok($out eq "Hi, Alice! You have 5 items.", "multi var: " . $out);

# No match
$tpl = "No vars here";
$out = render($tpl, name => "ignored");
ok($out eq "No vars here", "no match");

# Repeated var
$tpl = "{{ x }} and {{ x }} again";
$out = render($tpl, x => "Y");
ok($out eq "Y and Y again", "repeated var");

# Build an HTML table
sub html_table {
    my ($headers, @rows) = @_;
    my $html = "<table>\n<tr>";
    foreach my $h (@{$headers}) {
        $html .= "<th>" . $h . "</th>";
    }
    $html .= "</tr>\n";
    foreach my $row (@rows) {
        $html .= "<tr>";
        foreach my $cell (@{$row}) {
            $html .= "<td>" . $cell . "</td>";
        }
        $html .= "</tr>\n";
    }
    $html .= "</table>";
    return $html;
}

my $table = html_table(["Name", "Age"], ["Alice", "30"], ["Bob", "25"]);
ok(index($table, "<th>Name</th>") >= 0, "table header");
ok(index($table, "<td>Alice</td>") >= 0, "table data");
ok(index($table, "<td>25</td>") >= 0, "table data 2");

print "\nPassed: " . $pass . "\nFailed: " . $fail . "\n";
if ($fail == 0) { print "All template tests passed!\n"; }
