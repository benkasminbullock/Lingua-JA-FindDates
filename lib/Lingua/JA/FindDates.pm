package Lingua::JA::FindDates;

use 5.010000;
require Exporter;
use AutoLoader qw(AUTOLOAD);
our @ISA = qw(Exporter);
@EXPORT_OK= qw/subsjdate kanji2number/;
our $VERSION = '0.015';
use warnings;
use strict;
use Carp;
use utf8;

# Kanji number conversion table.

my %kanjinums = 
(
〇 => 0,
一 => 1,
二 => 2,
三 => 3,
四 => 4,
五 => 5,
六 => 6,
七 => 7,
八 => 8,
九 => 9,
十 => 10,
百 => 100,
千 => 1000, # Dates shouldn't get any bigger than this X a digit
); 

# The kanji digits.

my $kanjidigits = join ('', keys %kanjinums);

sub kanji2number
{
    my ($knum) = @_;
    return 1 if $knum eq '元';
    my @kanjis = split '', $knum;
    my $value = 0;
    my $keta = 1;
    my @values;
    while (1) {
	my $k = pop @kanjis;
	return $value if ! defined $k;
	my $val = $kanjinums{$k};
        # Make sure this kanji number is one we know how to handle.
	if (! defined $val) {
	    warn "can't cope with '$k' of input '$knum'";
	    return 0;
	}
        # If the value of the individual kanji is more than 10.
	if ($val >= 10) {
	    $keta = $val;
	    my $knext = pop @kanjis;
	    if (!$knext) {
		return $value + $val;
	    }
	    my $val_next = $kanjinums{$knext};
	    if (!defined $val_next) {
		warn "can't cope with '$knext' of input '$knum'.\n";
		return 0;
	    }
	    if ($val_next > 10) {
		push @kanjis, $knext;
		$value += $val;
	    }
            else {
		$value += $val_next * $val;
	    }
	}
        else {
            # $k is a kanji digit from 0 to 9, and $val is its value.
	    $value += $val * $keta;
	    $keta *= 10;
	}
    }
}

# Map "double-byte" or "double-width" numbers to single byte numbers
# (the usual ASCII numbers).

my $nums = '０１２３４５６７８９';
my @wnums = split '', $nums;
my %wtonarrow;
for (0..9) {
    $wtonarrow{$wnums[$_]} = $_;
}
my $jdigit = '[０-９0-9]';
# A regular expression to match Japanese numbers
my $jnumber = "($jdigit+|[$kanjidigits]+)";
# A regular expression to match a Western year
my $wyear = '('.$jdigit.'{4}|['.$kanjidigits.']?千['.$kanjidigits.']*|'.
    '[\']'.$jdigit.'{2}'.
    ')\s*年';

# The recent era names (Heisei, Showa, Taisho, Meiji). These eras are
# sometimes written using the letters H, S, T, and M.
my $jera = '(H|Ｈ|平成|S|Ｓ|昭和|T|Ｔ|大正|M|Ｍ|明治)';

# A map of Japanese eras to Western dates.
my %jera2w = (
H    => 1988,
Ｈ   => 1988,
平成 => 1988,
S    => 1925,
Ｓ   => 1925,
昭和 => 1925,
T    => 1911,
Ｔ   => 1911,
大正 => 1911,
M    => 1869,
Ｍ   => 1869,
明治 => 1869,
);

#  ____                               
# |  _ \ ___  __ _  _____  _____  ___ 
# | |_) / _ \/ _` |/ _ \ \/ / _ \/ __|
# |  _ <  __/ (_| |  __/>  <  __/\__ \
# |_| \_\___|\__, |\___/_/\_\___||___/
#            |___/                    

# Japanese year, with era like "Heisei" at the beginning.

my $jyear = qr/$jera\h*($jdigit+|[$kanjidigits]+|元)\h*年/;

# The "jun" or approximately ten day periods (thirds of a month)

my %jun = qw/初 1 上 1 中 2 下 3/;

# The translations of the "jun" above into English.

my @jun2english = ('invalid', 'early ', 'mid-', 'late ');

# Japanese days of the week, from Monday to Sunday.

my $weekdays = '月火水木金土日';
my @weekdays = split '',$weekdays;

# Match a string for a weekday, like 月曜日 or (日)
# The long part (?=\W) is to stop it from accidentally matching a
# kanji which is part of a different word, like the following:
#平成二十年七月一日
#    日本論・日本人論は非常に面白いものだ。

my $match_weekday =
    qr/[（(]?([$weekdays])(?:(?:(?:曜日|曜)[)\）])|[)\）]|(?=\W))/;

# my $match_weekday = '[（(]?(['.$weekdays.'])(?:曜日|曜)?[)）]?';

# Match a day of the month, like 10日

my $match_dom = qr/$jnumber\h*日/;

# Match a month

my $match_month = qr/$jnumber\h*月/;

# Match a "jun" (a third of a month).

my $match_jun = '(['.join ('', keys %jun).'])\h*旬';

# Match a month+jun

my $match_month_jun = $match_month.'\h*'.$match_jun;

# Match a month and day of month pair

my $match_month_day = $match_month.'\h*'.$match_dom;

# Match a Japanese year, month, day string

my $matchymd = $jyear.'\h*'.$match_month_day;

# Match a Western year, month, day string

my $matchwymd = $wyear.'\h*'.$match_month_day;

# Match a Japanese year and month only

my $match_jyear_month = $jyear.'\h*'.$match_month;

# Match a Western year and month only

my $match_wyear_month = $wyear.'\h*'.$match_month;

# Match a month, day, weekday.

my $match_month_day_weekday = $match_month_day.'\h*'.$match_weekday;

# Separators used in date strings
# Microsoft Word uses Unicode 0xFF5E, the "fullwidth tilde", for nyoro symbol.

my $separators = '\h*[〜−~]\h*';
 
# =head2 Matching patterns

# I<The module can be used without reading this section>.

# The Japanese date regular expressions are stored in an array
# B<jdatere> containing a pair of a regular expression to match a kind
# of date, and a string like "ymdw" which contains letters saying what
# to do with $1, $2, etc. from the regular expression. The array
# B<jdatere> is ordered from longest match (like "year / month / day /
# weekday") to shortest (like "year" only). For example, if the first
# letter is "y", then $1 is a year in Western format like 2008, or if
# the third letter is "w", then $3 is the day of the week, from 1 to 7.

# =over

# =item e

# Japanese era (string).

# =item j

# Japanese year (string representing small number)

# =item x

# empty month and day

# =item m

# month number (from 1 to 12, 13 for a blank month, 0 for an invalid month)

# =item d

# day of month (from 1 to 31, 32 for a blank day, 0 for an invalid day)

# =item w

# weekday (from Monday = 1 to Sunday = 7, zero or undefined for an
# invalid weekday)

# =item z

# jun (旬), a ten day period.

# =item 1

# After another code, indicates the first of a pair of two things. For
# example, the matching code for

#   平成９年１０月１７日〜２０日

# is

#   ejmd1d2

# =back

# =cut

#  _     _     _            __                                     
# | |   (_)___| |_    ___  / _|  _ __ ___  __ _  _____  _____  ___ 
# | |   | / __| __|  / _ \| |_  | '__/ _ \/ _` |/ _ \ \/ / _ \/ __|
# | |___| \__ \ |_  | (_) |  _| | | |  __/ (_| |  __/>  <  __/\__ \
# |_____|_|___/\__|  \___/|_|   |_|  \___|\__, |\___/_/\_\___||___/
#                                         |___/                    

# This a list of date regular expressions.

my @jdatere = (

# Match an empty string like 平成 月 日 as found on a form etc.

[$jyear.'(\h+)月\h+日', "ejx"],

# Add match for dummy strings here

# Match a Japanese era, year, 2 x (month day weekday) combination

[$matchymd.'\h*'.$match_weekday.$separators.
 $match_month_day_weekday, "ejm1d1w1m2d2w2"],

# Match a Japanese era, year, month 2 x (day, weekday) combination

[$matchymd.$match_weekday.$separators.$match_dom.'\h*'.$match_weekday, 
 "ejmd1w1d2w2"],

# Match a Japanese era, year, month 2 x day combination

[$matchymd.$separators.$match_dom.'\h*'.$match_weekday, "ejmd1d2"],

# Match a Western year, 2x(month, day, weekday) combination

[$matchwymd.'\h*'.$match_weekday.$separators.$match_month_day_weekday,
 "ym1d1w1m2d2w2"],

# Match a Western year, month, 2x(day, weekday) combination

[$matchwymd.'\h*'.$match_weekday.$separators.$match_dom.'\h*'.$match_weekday,
 "ymd1w1d2w2"],

# Match a Western year, month, 2x(day) combination

[$matchwymd.$separators.$match_dom,
 "ymd1d2"],

# Match a Japanese era, year, month1 day1 - month 2 day2 combination

[$matchymd.$separators.$match_month_day, "ejm1d1m2d2"],

# Match a Japanese era, year, month1 - month 2 combination

[$jyear.'\h*'.$jnumber.'\h*月?'.$separators.$match_month, "ejm1m2"],

# Match a Japanese era, year, month, day1 - day2 combination

[$match_jyear_month.'\h*'.$jnumber.'\h*日?'.$separators.$match_dom, "ejmd1d2"],

# Match a Japanese era, year, month, day, weekday combination

[$matchymd.'\h*'.$match_weekday     , "ejmdw"],

# Match a Japanese era, year, month, day

[$matchymd                     , "ejmd"],

# Match a Japanese era, year, month, jun

[$match_jyear_month.'\h*'.$match_jun    , "ejmz"],

# Match a Western year, month, day, weekday combination

[$matchwymd.'\h*'.$match_weekday    , "ymdw"],

# Match a Western year, month, day combination

[$matchwymd           	       , "ymd"],

# Match a Western year, month, jun combination

[$match_wyear_month.'\h*'.$match_jun     , "ymz"],

# Match a Japanese era, year, month

[$jyear.'\h*'.$jnumber.'\h*月' , "ejm"],

# Match a Western year, month

[$match_wyear_month     , "ym"],

# Match 2 x (month, day, weekday)

[$match_month_day_weekday.$separators.$match_month_day_weekday, 
 "m1d1w1m2d2w2"],

# Match month, 2 x (day, weekday)

[$match_month_day_weekday.$separators.$match_dom.'\h*'.$match_weekday,
 "md1w1d2w2"],

# Match month, 2 x (day, weekday)

[$match_month_day.$separators.$match_dom,
 "md1d2"],

# Match a month, day, weekday

[$match_month_day_weekday     , "mdw"],

# Match a month, day

[$match_month_day              , "md"],

# Match a fiscal year (年度, nendo in Japanese). These usually don't
# have months combined with them, so there is nothing to match a
# fiscal year with a month.

[$jyear.'度'                   , "en"],

# Match a fiscal year (年度, nendo in Japanese). These usually don't
# have months combined with them, so there is nothing to match a
# fiscal year with a month.

[$wyear.'度'                   , "n"],

# Match a Japanese era, year

[$jyear,                        "ej"],

# Match a Western year

[$wyear                        , "y"],

# Match a month with a jun

[$match_month.'\h*'.$match_jun , "mz"],

# Match a month

[$match_month                    , "m"],

);

my @months = qw/Invalid
                January
                February
                March
                April
                May
                June
                July
		August
                September
                October
                November
                December
                MM/;

my @days = qw/Invalid
              Monday
              Tuesday
              Wednesday
              Thursday
              Friday
              Saturday
              Sunday/;

# This is a translation table from the Japanese weekday names to the
# English ones.

my %j2eweekday;

@j2eweekday{@weekdays} = (1..7);

# This is the default routine for turning a Japanese date into a
# foreign-style one.

sub make_date
{
    my ($datehash) = @_;
    my ($year, $month, $date, $wday, $jun) = 
	@{$datehash}{qw/year month date wday jun/};
    if (!$year && !$month && !$date && !$jun) {
	carp "No valid inputs\n";
	return;
    }
    my $edate = '';
    $edate = $days[$wday].", " if $wday;
    if ($month) {
	$month = int ($month); # In case it is 07 etc.
	$edate .= $months[$month];
	if ($jun) {
	    $edate = $jun2english[$jun] . $edate;
	}
    }
    if ($date) {
	$edate .= " " if length ($edate);
	$date = int ($date); # In case it is 07 etc.
	$date = "DD" if $date == 32;
	if ($year) {
	    $edate .= "$date, $year";
	} else {
	    $edate .= "$date";
	}
    } elsif ($year) {
	$edate .= " " if length ($edate);
	$edate .= $year;
    }
    return $edate;
}

# This is the default routine for turning a date interval into a
# foreign-style one, which is then substituted into the text.

sub make_date_interval
{
    my ($date1, $date2) = @_;
    my $einterval = '';
    my $usecomma;
    # The case of an interval with different years doesn't need to be
    # considered, because each date in that case can be considered a
    # single date.

    if ($date2->{month}) {
	if (!$date1->{month}) {
	    carp "end month but no starting month";
	    return;
	}
    }
    if ($date1->{month}) {
	if ($date1->{wday} && $date2->{wday}) {
	    if (! $date1->{date} || ! $date2->{date}) {
		carp "malformed date has weekdays but not days of month";
		return;
	    }
	    $usecomma = 1;
	    $einterval = $days[$date1->{wday}]  . " " . $date1->{date} .
		         ($date2->{month} ? ' '.$months[int ($date1->{month})] : ''). '-' .
		         $days[$date2->{wday}]  . " " . $date2->{date} . " " .
			 ($date2->{month} ? $months[int ($date2->{month})] : $months[int ($date1->{month})]);
	}
        elsif ($date1->{date} && $date2->{date}) {
	    $usecomma = 1;
	    if ($date1->{wday} || $date2->{wday}) {
		carp "malformed date interval: ",
		    "has weekday for one date but not the other one.";
		return;
	    }
	    $einterval = $months[int ($date1->{month})] . ' ' .
		         $date1->{date} . '-' .
			 ($date2->{month} ? 
			  $months[int ($date2->{month})] . ' ' : '') .
		         $date2->{date};
	}
        else { # no dates or weekdays
	    if ($date1->{date} || $date2->{date}) {
		carp "malformed date interval: only one day of month";
		return;
	    }
	    if (!$date2->{month}) {
		carp "start month but no end month or date";
		return;
	    }
	    $einterval = $months[int($date1->{month})] . '-' . 
		         $months[int($date2->{month})] .
			 $einterval;
	}
    }
    else { # weekday - day / weekday - day case.
	if ($date1->{wday} && $date2->{wday}) {
	    if (! $date1->{date} || ! $date2->{date}) {
		carp "malformed date has weekdays but not days of month";
		return;
	    }
	    $einterval = $date1->{wday}  . " " . $date1->{date} . '-' .
		         $date2->{wday}  . " " . $date2->{date};
	}
    }
    $einterval .= ($usecomma ? ', ': ' ').$date1->{year} if $date1->{year};
    return $einterval;
}

# If you want to see what the module is doing, set
#
#   $Lingua::JA::FindDates::verbose = 1;
#
# This makes L<subsjdate> print out each regular expression and reports
# whether it matched, which looks like this:
#
#   Looking for y in ([０-９0-9]{4}|[十六七九五四千百二一八三]?千[十六七九五四千百二一八三]*)\h*年
#   Found '千九百六十六年': Arg 0: 1966 -> '1966'

our $verbose = 0;

sub subsjdate
{
    # $text is the text to substitute. It needs to be in Perl's
    # internal encoding.
    # $replace_callback is a routine to call back if we find valid dates.
    # $data is arbitrary data to pass to the callback routine.
    my ($text, $callbacks) = @_;
    # Save doing existence tests.
    if (! $callbacks) {
        $callbacks = {};
    }
    if (! $text) {
        return $text;
    }
    # Loop through all the possible regular expressions.
    for my $datere (@jdatere) {
	my $regex = $$datere[0];
	my @process = split (/(?=[a-z][12]?)/, $$datere[1]);
        if ($verbose) {
            print "Looking for ",$$datere[1]," in ",$regex,"\n";
        }
	while ($text =~ /($regex)/g) {
	    my $date1;
	    my $date2;
            # The matching string is in the following variable.
	    my $orig = $1;
	    my @matches = ($2,$3,$4,$5,$6,$7,$8,$9);
            if ($verbose) {
                print "Found '$orig': " if $verbose;
            }
	    for (0..$#matches) {
		my $arg = $matches[$_];

		last if !$arg;
		$arg =~ s/([０-９])/$wtonarrow{$1}/g;
		$arg =~ s/([$kanjidigits]+|元)/kanji2number($1)/ge;
                if ($verbose) {
                    print "Arg $_: $arg " if $verbose;
                }
		my $argdo = $process[$_];
		if ($argdo eq 'e') { # Era name in Japanese
		    $date1->{year} = $jera2w{$arg};
		}
                elsif ($argdo eq 'j') { # Japanese year
		    $date1->{year} += $arg;
		}
                elsif ($argdo eq 'y') {
		    $date1->{year} = $arg;
		}
                elsif ($argdo eq 'n') {
		    $date1->{year} += $arg;
		    $date1->{year} = "fiscal ".$date1->{year};
		}
                elsif ($argdo eq 'm' || $argdo eq 'm1') {
		    $date1->{month} = $arg;
		}
                elsif ($argdo eq 'd' || $argdo eq 'd1') {
		    $date1->{date} = $arg;
		}
                elsif ($argdo eq 'm2') {
		    $date2->{month} = $arg;
		}
                elsif ($argdo eq 'd2') {
		    $date2->{date} = $arg;
		}
                elsif ($argdo eq 'w' || $argdo eq 'w1') {
		    $date1->{wday} = $j2eweekday{$arg};
		}
                elsif ($argdo eq 'w2') {
		    $date2->{wday} = $j2eweekday{$arg};
		}
                elsif ($argdo eq 'z') {
		    $date1->{jun} = $jun{$arg};
		}
                elsif ($argdo eq 'x') {
                    if ($verbose) {
                        print "Dummy date '$orig'.\n" if $verbose;
                    }
		    $date1->{date}  = 32;
		    $date1->{month} = 13;
		}
	    }
	    my $edate;
	    if ($date2) {
                # Date interval
		if ($callbacks->{make_date_interval}) {
		    $edate = 
                    &{$callbacks->{make_date_interval}} ($callbacks->{data},
                                                         $orig,
                                                         $date1, $date2);
		}
                else {
		    $edate = make_date_interval ($date1, $date2);
		}
	    }
            else {
                # Single date
		if ($callbacks->{make_date}) {
		    $edate = &{$callbacks->{make_date}}($callbacks->{data},
                                                        $orig,
                                                        $date1);
		}
                else {
		    $edate = make_date ($date1);
		}
	    }
            if ($verbose) {
                print "-> '$edate'\n" if $verbose;
            }


	    $text =~ s/\Q$orig\E/$edate/g;
	    if ($callbacks &&
                $callbacks->{replace}) {
		&{$callbacks->{replace}}($callbacks->{data}, $orig, $edate);
	    }
	}
    }
    return $text;
}

1;

__END__

