use strict;
use warnings;

our $pass = 0;
our $fail = 0;
sub ok { my ($test, $name) = @_; if ($test) { $pass++; } else { $fail++; print "FAIL: $name\n"; } }

sub markdown_to_html {
    my ($text) = @_;
    my @lines = split(/\n/, $text);
    my $html = "";
    my $in_list = 0;
    my $in_code = 0;

    foreach my $line (@lines) {
        # Code blocks
        if ($line =~ /^```/) {
            if ($in_code) {
                $html .= "</code></pre>\n";
                $in_code = 0;
            } else {
                $html .= "<pre><code>\n";
                $in_code = 1;
            }
            next;
        }
        if ($in_code) {
            $html .= $line . "\n";
            next;
        }

        # Headers
        if ($line =~ /^### (.+)/) {
            $html .= "<h3>" . $1 . "</h3>\n";
            next;
        }
        if ($line =~ /^## (.+)/) {
            $html .= "<h2>" . $1 . "</h2>\n";
            next;
        }
        if ($line =~ /^# (.+)/) {
            $html .= "<h1>" . $1 . "</h1>\n";
            next;
        }

        # Unordered list
        if ($line =~ /^- (.+)/) {
            if (!$in_list) {
                $html .= "<ul>\n";
                $in_list = 1;
            }
            $html .= "<li>" . $1 . "</li>\n";
            next;
        } elsif ($in_list) {
            $html .= "</ul>\n";
            $in_list = 0;
        }

        # Bold and italic
        $line =~ s/\*\*(.+?)\*\*/<strong>$1<\/strong>/g;
        $line =~ s/\*(.+?)\*/<em>$1<\/em>/g;

        # Inline code
        $line =~ s/`(.+?)`/<code>$1<\/code>/g;

        # Links
        $line =~ s/\[(.+?)\]\((.+?)\)/<a href="$2">$1<\/a>/g;

        # Paragraph (non-empty lines)
        if (length($line) > 0) {
            $html .= "<p>" . $line . "</p>\n";
        }
    }
    if ($in_list) { $html .= "</ul>\n"; }
    return $html;
}

# Test it
my $md = "# Hello World

This is **bold** and *italic*.

## Features

- Item one
- Item two
- Item three

Check out [Strada](https://strada-lang.org).

### Code Example

```
my \$x = 42;
```

Done!";

my $html = markdown_to_html($md);

ok(index($html, "<h1>Hello World</h1>") >= 0, "h1");
ok(index($html, "<strong>bold</strong>") >= 0, "bold");
ok(index($html, "<em>italic</em>") >= 0, "italic");
ok(index($html, "<h2>Features</h2>") >= 0, "h2");
ok(index($html, "<li>Item one</li>") >= 0, "list item");
ok(index($html, "<ul>") >= 0, "ul open");
ok(index($html, "</ul>") >= 0, "ul close");
ok(index($html, '<a href="https://strada-lang.org">Strada</a>') >= 0, "link: " . $html);
ok(index($html, "<h3>Code Example</h3>") >= 0, "h3");
ok(index($html, "<pre><code>") >= 0, "code block");
ok(index($html, "Done!") >= 0, "text after code");

print "\nPassed: " . $pass . "\nFailed: " . $fail . "\n";
if ($fail == 0) { print "All markdown tests passed!\n"; }
