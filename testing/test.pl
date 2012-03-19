#!/home/ben/software/install/bin/perl

use warnings;
use strict;
use utf8;
use lib '../lib/';
use Lingua::JA::FindDates 'subsjdate';
binmode STDOUT, "utf8";

my $test5 =<<EOF;
2008年07月03日 01:39:21 投稿
【西村修平・桜井誠編】平成20年7月2日毎日新聞社前抗議行動！
最低賃金法が大きく改正され、平成２０年７月１日から施行されました。
平成二十年七月四日
Opera 9.51(Windows版)を入れてみたけれども相變らず使ひ物にならない。何なんだらう。
日本義塾 平成二十年七月公開講義
公開日時：2008年06月28日 01時09分
更新日時：2008年06月29日 00時08分

◎【日本義塾七月公開講義】

　◎日　時　平成二十年七月二十五日（金）
　　　　　　午後六時半～九時（六時開場）
H20年7月壁紙
7月壁紙（1024×768）を作成しました（クリックすると拡大します）。
昭和４９年度
1999年度
EOF

#$Lingua::JA::FindDates::verbose = 1;

sub replace_callback
{
    my ($data, $jdate, $edate) = @_;
    print "$jdate -> $edate\n";
}
#print $test5;
subsjdate ($test5, {replace => \&replace_callback});
