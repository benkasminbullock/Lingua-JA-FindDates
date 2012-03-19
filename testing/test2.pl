#!/home/ben/software/install/bin/perl

use warnings;
use strict;
use utf8;
use lib '../lib/';
use Lingua::JA::FindDates 'subsjdate';
binmode STDOUT, "utf8";
my $has_newline =<<EOF;
平成二十年七月一日
    日本論・日本人論は非常に面白いものだ。
EOF

#$Lingua::JA::FindDates::verbose = 1;

print subsjdate($has_newline);
