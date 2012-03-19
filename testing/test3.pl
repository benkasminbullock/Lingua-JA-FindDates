#!/home/ben/software/install/bin/perl

use warnings;
use strict;
use utf8;
use lib './blib/lib/';
use Lingua::JA::FindDates 'subsjdate';
#$Lingua::JA::FindDates::verbose = 1;# 'subsjdate';
binmode STDOUT, "utf8";
# my @tests_interval = 
# ('昭和41年3月1〜12日',
#  '昭和41年3月1日〜12日',
#  '昭和41年1〜12月',
#  '昭和41年1月〜12月',
#  '昭和41年3月1日〜4月12日',
#  '昭和41年3月1日〜4月12日',
# '三月一日（木）〜３日（土）',
# '2008年7月一日（木）〜八月３日（土)',
# );

# for my $c (@tests_interval[0..1]) {
#     print "Looking for $c\n";
#     print $c, " ", subsjdate($c),"\n";
# }
# for my $c (@tests_interval[2..3]) {
#     print "Looking for $c\n";
#     print $c, " ", subsjdate($c),"\n";
# }
# for my $c (@tests_interval[4..5]) {
#     print "Looking for $c\n";
#     print $c, " ", subsjdate($c),"\n";
# }
# for my $c (@tests_interval[6..7]) {
#     print "Looking for $c\n";
#     print $c, " ", subsjdate($c),"\n";
# }
#'Thursday 1-Saturday 3 March'
#'Thursday July 1-Saturday August 3, 2008'
#print subsjdate ('2008年7月一日（木）〜３日（土)'),"\n";
print subsjdate ('平成９年１０月１７日（火）〜２０日（金）'),"\n";
