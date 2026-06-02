#!/usr/bin/perl
use warnings;
use Test::More;
use File::Temp;

# File::Temp's OO form: File::Temp->new returns the open filehandle
# blessed into File::Temp, with the temp filename stashed in the glob's
# SCALAR slot (`${*$self}`) and a '""' overload that returns it. This
# exercises three perla value-model additions: bless on a filehandle,
# `${*$fh}` glob-scalar-slot store/fetch, and '""' overload dispatch on
# a blessed filehandle.

# Raw mechanism: bless a filehandle + glob scalar slot.
{
    open(my $fh, ">", "/tmp/perla_ftoo_$$") or die;
    ${*$fh} = "stashed-path";
    is(${*$fh}, "stashed-path", "\${*\$fh} stores/reads the glob scalar slot");
    my $b = bless $fh, "My::FH";
    is(ref($fh), "My::FH", "bless works on a filehandle");
    close $fh;
    unlink "/tmp/perla_ftoo_$$";
}

# File::Temp->new end to end.
{
    my $f = File::Temp->new(SUFFIX => ".dat");
    isa_ok($f, "File::Temp", "File::Temp->new returns a File::Temp object");
    like($f->filename, qr/\.dat$/, "->filename returns the temp path");
    is("$f", $f->filename, "stringify ('\"\"' overload) == filename");
    like("$f", qr/\.dat$/, "interpolation gives the temp path");
    ok(-e "$f", "the temp file exists on disk");

    # Writable through the handle.
    print $f "payload\n";
    close $f;
    open(my $r, "<", "$f") or die;
    my $line = <$r>;
    close $r;
    is($line, "payload\n", "data written through the File::Temp handle is readable");
}

# Functional tempfile() still works alongside.
{
    use File::Temp qw(tempfile);
    my ($fh, $name) = tempfile(SUFFIX => ".tmp");
    like($name, qr/\.tmp$/, "functional tempfile() returns a name");
    ok(-e $name, "functional tempfile() created the file");
    close $fh;
    unlink $name;
}

done_testing;
