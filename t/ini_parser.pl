use strict;
use warnings;

our $pass = 0;
our $fail = 0;
sub ok { my ($test, $name) = @_; if ($test) { $pass++; } else { $fail++; print "FAIL: $name\n"; } }

# INI file parser
sub parse_ini {
    my ($text) = @_;
    my %config = ();
    my $section = "default";
    my @lines = split(/\n/, $text);
    foreach my $line (@lines) {
        $line =~ s/^\s+//;
        $line =~ s/\s+$//;
        next if length($line) == 0;
        next if substr($line, 0, 1) eq "#";
        next if substr($line, 0, 1) eq ";";

        # Section header [section]
        if ($line =~ /^\[(.+)\]$/) {
            $section = $1;
            if (!exists($config{$section})) {
                $config{$section} = {};
            }
            next;
        }

        # Key = value
        if (index($line, "=") >= 0) {
            my $eq_pos = index($line, "=");
            my $key = substr($line, 0, $eq_pos);
            my $val = substr($line, $eq_pos + 1, length($line) - $eq_pos - 1);
            $key =~ s/^\s+//;
            $key =~ s/\s+$//;
            $val =~ s/^\s+//;
            $val =~ s/\s+$//;
            if (!exists($config{$section})) {
                $config{$section} = {};
            }
            $config{$section}->{$key} = $val;
        }
    }
    return %config;
}

sub ini_get {
    my ($config, $section, $key) = @_;
    if (exists($config->{$section}) && exists($config->{$section}{$key})) {
        return $config->{$section}{$key};
    }
    return undef;
}

sub ini_sections {
    my ($config) = @_;
    return sort(keys(%{$config}));
}

# Generate INI back
sub to_ini {
    my ($config) = @_;
    my $out = "";
    foreach my $sec (sort(keys(%{$config}))) {
        $out .= "[" . $sec . "]\n";
        my $section = $config->{$sec};
        foreach my $key (sort(keys(%{$section}))) {
            $out .= $key . " = " . $section->{$key} . "\n";
        }
        $out .= "\n";
    }
    return $out;
}

my $ini_text = "[database]
host = localhost
port = 5432
name = mydb

[server]
# Server settings
host = 0.0.0.0
port = 8080
workers = 4

[logging]
level = info
file = /var/log/app.log";

my %config = parse_ini($ini_text);
my $cfg = \%config;

ok(ini_get($cfg, "database", "host") eq "localhost", "db host");
ok(ini_get($cfg, "database", "port") eq "5432", "db port");
ok(ini_get($cfg, "database", "name") eq "mydb", "db name");
ok(ini_get($cfg, "server", "host") eq "0.0.0.0", "server host");
ok(ini_get($cfg, "server", "port") eq "8080", "server port");
ok(ini_get($cfg, "server", "workers") eq "4", "workers");
ok(ini_get($cfg, "logging", "level") eq "info", "log level");
ok(!defined(ini_get($cfg, "missing", "key")), "missing section");

my @secs = ini_sections($cfg);
ok(scalar(@secs) == 3, "section count");
ok($secs[0] eq "database", "first section");

# Round-trip
my $regenerated = to_ini($cfg);
ok(index($regenerated, "host = localhost") >= 0, "roundtrip host");
ok(index($regenerated, "[server]") >= 0, "roundtrip section");

# Modify and check
$config{"database"}{"port"} = "3306";
ok(ini_get($cfg, "database", "port") eq "3306", "modify port");

print "\nPassed: " . $pass . "\nFailed: " . $fail . "\n";
if ($fail == 0) { print "All INI tests passed!\n"; }
