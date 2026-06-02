use strict;
use warnings;

# A simple INI-style config file parser

package Config;

sub new {
    my ($class) = @_;
    return bless({
        sections => {},
        current  => "default",
    }, $class);
}

sub parse_string {
    my ($self, $text) = @_;
    my @lines = split("\n", $text);
    foreach my $line (@lines) {
        # Skip empty lines and comments
        next if length($line) == 0;
        my $first = substr($line, 0, 1);
        next if $first eq "#";
        next if $first eq ";";

        # Section header [section]
        if ($first eq "[") {
            my $end = index($line, "]");
            if ($end > 1) {
                $self->{current} = substr($line, 1, $end - 1);
                if (!exists($self->{sections}{$self->{current}})) {
                    $self->{sections}{$self->{current}} = {};
                }
            }
            next;
        }

        # Key = Value
        my $eq = index($line, "=");
        if ($eq > 0) {
            my $key = substr($line, 0, $eq);
            my $val = substr($line, $eq + 1);
            # Trim spaces (simple version)
            $key =~ s/^\s+//;
            $key =~ s/\s+$//;
            $val =~ s/^\s+//;
            $val =~ s/\s+$//;

            my $section = $self->{current};
            if (!exists($self->{sections}{$section})) {
                $self->{sections}{$section} = {};
            }
            $self->{sections}{$section}{$key} = $val;
        }
    }
}

sub get {
    my ($self, $section, $key) = @_;
    if (exists($self->{sections}{$section})) {
        if (exists($self->{sections}{$section}{$key})) {
            return $self->{sections}{$section}{$key};
        }
    }
    return undef;
}

sub sections {
    my ($self) = @_;
    return sort(keys(%{$self->{sections}}));
}

sub keys_in {
    my ($self, $section) = @_;
    if (exists($self->{sections}{$section})) {
        return sort(keys(%{$self->{sections}{$section}}));
    }
    my @empty = ();
    return @empty;
}

sub dump_config {
    my ($self) = @_;
    my @sects = $self->sections();
    foreach my $s (@sects) {
        print "[" . $s . "]\n";
        my @ks = $self->keys_in($s);
        foreach my $k (@ks) {
            print "  " . $k . " = " . $self->get($s, $k) . "\n";
        }
    }
}

package main;

my $ini_text = "[database]
host = localhost
port = 5432
name = myapp_db

[server]
host = 0.0.0.0
port = 8080
workers = 4

# This is a comment
[logging]
level = info
file = /var/log/app.log";

my $config = Config::new("Config");
$config->parse_string($ini_text);

# Dump all config
$config->dump_config();

# Direct access
print "\nDB host: " . $config->get("database", "host") . "\n";
print "Server port: " . $config->get("server", "port") . "\n";
print "Log level: " . $config->get("logging", "level") . "\n";

# Test missing key
my $missing = $config->get("database", "password");
if (!defined($missing)) {
    print "password: (not set)\n";
}

# Test sections list
my @sects = $config->sections();
print "Sections: " . join(", ", @sects) . "\n";

print "\nConfig parser test passed!\n";
