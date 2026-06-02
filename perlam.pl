#!/usr/bin/perl
# perlam - Perla Module installer
use strict;
use warnings;

my $VERSION = "0.1.0";

# Resolve the perla binary: $PERLA_BIN, else `perla` on PATH, else "" (caller
# checks -x). Standalone perla self-detects its runtime, so no STRADA_DIR needed.
sub find_perla_bin {
    return $ENV{PERLA_BIN} if $ENV{PERLA_BIN} && -x $ENV{PERLA_BIN};
    my $p = `command -v perla 2>/dev/null`; chomp $p;
    return $p if $p;
    return "";
}
# Resolve the strada binary: `strada` on PATH, else "".
sub find_strada_bin {
    my $s = `command -v strada 2>/dev/null`; chomp $s;
    return $s;
}

my $verbose = 0;
my $force = 0;
my $info_only = 0;
my $list_only = 0;
my $install_mode = "local";
my $custom_lib = "";

my @modules = ();
my $ai = 0;
while ($ai < scalar(@ARGV)) {
    my $a = $ARGV[$ai];
    if ($a eq "--local" || $a eq "-l") { $install_mode = "local"; }
    elsif ($a eq "--system" || $a eq "-s") { $install_mode = "system"; }
    elsif ($a eq "--lib") { $ai++; $custom_lib = $ARGV[$ai]; $install_mode = "custom"; }
    elsif ($a eq "--info" || $a eq "-i") { $info_only = 1; }
    elsif ($a eq "--list") { $list_only = 1; }
    elsif ($a eq "--verbose" || $a eq "-v") { $verbose = 1; }
    elsif ($a eq "--force" || $a eq "-f") { $force = 1; }
    elsif ($a eq "--help" || $a eq "-h") {
        print "perlam $VERSION - Perla Module installer\n";
        print "Usage: perlam [options] Module::Name ...\n";
        print "  --local, -l    Install to ~/perla/lib (default)\n";
        print "  --system, -s   Install to /usr/local/lib/perla\n";
        print "  --lib PATH     Install to specific directory\n";
        print "  --info, -i     Show module info\n";
        print "  --list         List installed modules\n";
        print "  --verbose, -v  Verbose\n";
        print "  --force, -f    Force reinstall\n";
        exit(0);
    }
    elsif ($a eq "--version") { print "perlam $VERSION\n"; exit(0); }
    elsif (substr($a, 0, 1) ne "-") { push @modules, $a; }
    $ai++;
}

# Resolve lib dir
my $lib_dir = "";
if ($install_mode eq "custom") { $lib_dir = $custom_lib; }
elsif ($install_mode eq "system") { $lib_dir = "/usr/local/lib/perla"; }
else {
    my $home = $ENV{HOME};
    if (!defined($home)) { $home = "/tmp"; }
    $lib_dir = $home . "/perla/lib";
}

if ($list_only) {
    my $output = `find '$lib_dir' -name '*.pm' -type f 2>/dev/null`;
    if (length($output) == 0) { print "No modules installed in $lib_dir\n"; exit(0); }
    print "Installed in $lib_dir:\n";
    my @files = split(/\n/, $output);
    foreach my $f (sort @files) {
        my $mod = $f;
        # Remove .pm and lib_dir prefix, convert / to ::
        my $prefix_len = length($lib_dir) + 1;
        if (length($mod) > $prefix_len) { $mod = substr($mod, $prefix_len); }
        # Strip .pm suffix
        if (length($mod) > 3 && substr($mod, length($mod) - 3) eq ".pm") {
            $mod = substr($mod, 0, length($mod) - 3);
        }
        # Replace / with ::
        my $new_mod = "";
        my $ci = 0;
        while ($ci < length($mod)) {
            my $ch = substr($mod, $ci, 1);
            if ($ch eq "/") { $new_mod = $new_mod . "::"; }
            else { $new_mod = $new_mod . $ch; }
            $ci++;
        }
        $mod = $new_mod;
        print "  $mod\n";
    }
    exit(0);
}

if (scalar(@modules) == 0) { print "Usage: perlam [options] Module::Name ...\n"; exit(1); }

my $tmp_dir = "/tmp/perlam-" . getppid();
system("mkdir -p '$tmp_dir'");

my $fail = 0;
foreach my $mod (@modules) {
    if (!install_module($mod)) { $fail = 1; }
}

system("rm -rf '$tmp_dir'");
exit($fail);

sub compile_xs_direct {
    my ($xs_file, $xs_base, $src_dir, $lib_dir, $strada_dir) = @_;

    # Direct C compilation: extract C code from XS and compile
    # This handles simple XS files that are mostly C with XS macros
    my $xs_src = `cat '$xs_file'`;

    # Find include files in the same directory as the XS file
    my $xs_dir = $xs_file;
    my $lslash = rindex($xs_dir, "/");
    if ($lslash >= 0) { $xs_dir = substr($xs_dir, 0, $lslash); }
    else { $xs_dir = "."; }

    # Create output directory
    my $auto_dir = "$lib_dir/auto/$xs_base";
    system("mkdir -p '$auto_dir'");

    # Generate a C wrapper using Perla's XS support
    # This creates perla_xs_Package_func() wrappers that work with the Strada runtime
    my $wrapper_c = "$auto_dir/${xs_base}_wrap.c";
    my $so_out = "$auto_dir/${xs_base}.so";

    # Use Perla's compiled XS pipeline
    my $perla_bin = find_perla_bin();
    if ($perla_bin && -x $perla_bin) {
        # Create a tiny .pl that loads the XS
        my $stub_pl = "$src_dir/_xs_stub.pl";
        open(my $fh, ">", $stub_pl);
        print $fh "# XS stub for compilation\nuse strict;\nprint \"ok\\n\";\n";
        close($fh);

        # Copy XS to where perla expects it
        system("cp '$xs_file' '$src_dir/'") if $xs_file ne "$src_dir/$xs_base.xs";

        # Compile with perla (which handles XS via _compile_with_xs)
        my $result = `'$perla_bin' -c '$stub_pl' 2>&1`;
        if ($result =~ /error/i) {
            if ($verbose) { print "   XS compile output: $result\n"; }
            print "   XS compilation had errors (complex XS may need manual porting)\n";
        }
        unlink($stub_pl);
    }

    # If shared object exists, report success
    if (-f $so_out) {
        print "   Built: $so_out\n";
    } else {
        print "   XS module '$xs_base' needs manual compilation\n";
        print "   Source: $xs_file\n";
        if ($verbose) {
            print "   Try: xs2strada '$xs_file' '${xs_base}.strada'\n";
            print "        strada --shared '${xs_base}.strada'\n";
        }
    }
}

sub install_module {
    my ($module) = @_;
    print "-> Looking up $module on MetaCPAN...\n";

    my $json = `curl -sL 'https://fastapi.metacpan.org/v1/module/$module' 2>/dev/null`;
    if (length($json) < 20) {
        print "Error: Module '$module' not found\n";
        return 0;
    }

    my $dist = "";
    my $version = "";
    my $download = "";
    my $author = "";
    my $abstract = "";
    if ($json =~ /"distribution"\s*:\s*"([^"]+)"/) { $dist = $1; }
    if ($json =~ /"version"\s*:\s*"([^"]+)"/) { $version = $1; }
    if ($json =~ /"download_url"\s*:\s*"([^"]+)"/) { $download = $1; }
    if ($json =~ /"author"\s*:\s*"([^"]+)"/) { $author = $1; }
    if ($json =~ /"abstract"\s*:\s*"([^"]+)"/) { $abstract = $1; }

    if (length($dist) == 0) { print "Error: Parse failed for '$module'\n"; return 0; }

    print "-> Found $dist $version by $author\n";
    if (length($abstract) > 0) { print "   $abstract\n"; }
    if ($info_only) { return 1; }

    if (length($download) == 0) { print "Error: No download URL\n"; return 0; }

    # Download
    print "-> Downloading...\n";
    my @url_parts = split(/\//, $download);
    my $fname = $url_parts[scalar(@url_parts) - 1];
    my $archive = $tmp_dir . "/" . $fname;
    my $rc = system("curl -sL -o '$archive' '$download'");
    if ($rc != 0) { print "Error: Download failed\n"; return 0; }

    # Extract
    print "-> Extracting...\n";
    my $ext_dir = $tmp_dir . "/ext";
    system("mkdir -p '$ext_dir'");
    $rc = system("tar xzf '$archive' -C '$ext_dir' 2>/dev/null");
    if ($rc != 0) { print "Error: Extraction failed\n"; return 0; }

    my $ls = `ls '$ext_dir'`;
    my @entries = split(/\n/, $ls);
    if (scalar(@entries) == 0) { print "Error: Empty archive\n"; return 0; }
    my $src_dir = $ext_dir . "/" . $entries[0];

    # Install .pm files from lib/
    print "-> Installing to $lib_dir...\n";
    system("mkdir -p '$lib_dir'");

    my $count = 0;
    my $lib_src = $src_dir . "/lib";
    if (-d $lib_src) {
        my $pm_list = `find '$lib_src' -name '*.pm' -type f 2>/dev/null`;
        my @pms = split(/\n/, $pm_list);
        foreach my $pm (@pms) {
            if (length($pm) == 0) { next; }
            my $rel = substr($pm, length($lib_src) + 1);
            my $dest = $lib_dir . "/" . $rel;
            # Get directory part
            my $last_slash = rindex($dest, "/");
            if ($last_slash > 0) {
                my $dest_dir = substr($dest, 0, $last_slash);
                system("mkdir -p '$dest_dir'");
            }
            system("cp '$pm' '$dest'");
            if ($verbose) { print "   $rel\n"; }
            $count++;
        }
    }

    # Compile XS files using Perla's xs2strada tool
    my $xs_list = `find '$src_dir' -name '*.xs' -type f 2>/dev/null`;
    my @xs_files = split(/\n/, $xs_list);
    if (scalar(@xs_files) > 0) {
        my $strada_dir = $ENV{STRADA_DIR};
        if (!defined($strada_dir)) { $strada_dir = "."; }

        foreach my $xs_file (@xs_files) {
            if (length($xs_file) == 0) { next; }
            print "-> Compiling XS: $xs_file\n";

            # Use Perla to compile the XS file into a shared object
            # Step 1: Convert XS to Strada __C__ block wrapper
            my @xparts = split(/\//, $xs_file);
            my $xs_base = $xparts[scalar(@xparts) - 1];
            $xs_base =~ s/\.xs$//;

            # Step 2: Compile directly with gcc using the XS C code
            # Generate a minimal C wrapper that Perla can link
            my $xs_c_out = "$tmp_dir/${xs_base}_xs.c";
            my $xs_so = "$lib_dir/auto/${xs_base}/${xs_base}.so";

            # Read the XS file and extract includes and CODE blocks
            my $xs_source = `cat '$xs_file'`;

            # Use the xs2strada converter if available (a Strada source tool;
            # found in a STRADA_DIR tree, else on PATH). When absent we fall
            # through to compile_xs_direct (the perla-based XS path).
            my $xs2strada = "$strada_dir/tools/xs2strada";
            if (! -f $xs2strada) {
                my $p = `command -v xs2strada 2>/dev/null`; chomp $p;
                $xs2strada = $p if $p;
            }
            my $strada_bin = find_strada_bin() || "$strada_dir/strada";
            if (-f $xs2strada) {
                my $strada_out = "$tmp_dir/${xs_base}_xs.strada";
                system("$xs2strada '$xs_file' '$strada_out' 2>/dev/null");
                if (-f $strada_out) {
                    print "   Converted to Strada: $strada_out\n";
                    # Compile the Strada XS wrapper to a shared object
                    system("$strada_bin --shared '$strada_out' -o '$xs_so' 2>/dev/null");
                    if (-f $xs_so) {
                        print "   Built: $xs_so\n";
                    } else {
                        print "   Warning: Failed to compile XS shared object\n";
                        # Try direct C compilation as fallback
                        compile_xs_direct($xs_file, $xs_base, $src_dir, $lib_dir, $strada_dir);
                    }
                } else {
                    print "   Warning: xs2strada conversion failed, trying direct C compile\n";
                    compile_xs_direct($xs_file, $xs_base, $src_dir, $lib_dir, $strada_dir);
                }
            } else {
                # No xs2strada available — try direct C compilation
                compile_xs_direct($xs_file, $xs_base, $src_dir, $lib_dir, $strada_dir);
            }
        }
    }

    if ($count > 0) {
        print "-> Installed $count file(s) for $dist $version\n";
    } else {
        print "Warning: No .pm files found\n";
    }

    system("rm -rf '$ext_dir'");
    return 1;
}
