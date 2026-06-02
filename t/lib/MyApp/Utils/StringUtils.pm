package MyApp::Utils::StringUtils;

use strict;
use warnings;

sub trim {
    my ($str) = @_;
    $str =~ s/^\s+//;
    $str =~ s/\s+$//;
    return $str;
}

sub pad_right {
    my ($str, $width) = @_;
    while (length($str) < $width) {
        $str = $str . " ";
    }
    return $str;
}

sub repeat_str {
    my ($str, $n) = @_;
    return $str x $n;
}

1;
