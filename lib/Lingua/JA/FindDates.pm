package Lingua::JA::FindDates;

use 5.008000;
require Exporter;
use AutoLoader qw(AUTOLOAD);
our @ISA = qw(Exporter);
@EXPORT_OK= qw/subsjdate/;
our $VERSION = '0.013';
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

# The kanji converter is not a user-visible routine, so its
# documentation below is commented out.

# =head2 kanji2number

# =over

# =item kanji2number ($knum)

# C<kanji2number> is a very simple kanji number convertor. Its input is
# one string of kanji numbers only, like '三十一'. It can deal with
# kanji numbers with or without ten/hundred/thousand kanjis. The return
# value is the numerical value of the kanji number, like 31, or zero if
# it can't read the number.

# This function is not exported.

# =back

# =head3 Bugs

# kanji2number only goes up to thousands, because usually dates only go
# that far. If you need a comprehensive Japanese number convertor, we
# recommend using L<Lingua::JA::Numbers> instead of this. Also, it
# doesn't deal with mixed kanji and arabic numbers.

# =cut

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
	return $value if !$k;
	my $val = $kanjinums{$k};
	if (!defined $val) {
	    warn "can't cope with '$k' of input '$knum'";
	    return 0;
	}
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
	    } else {
		$value += $val_next * $val;
	    }
	} else {
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

# Japanese eras (Heisei, Showa, Taisho, Meiji). Japanese people
# sometimes write these eras using the letters H, S, T, and M.
my $jera = '(H|Ｈ|平成|S|Ｓ|昭和|T|Ｔ|大正|M|Ｍ|明治)';
# Map of Japanese eras to Western dates.
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

# Japanese year, with era like "Heisei" at the beginning.
my $jyear = $jera.'\h*('."$jdigit+|[$kanjidigits]+".'|元)\h*年';
# Ten day periods (thirds of a month)
my %jun = qw/初 1 上 1 中 2 下 3/;
my @jun2english = ('invalid', 'early ', 'mid-', 'late ');
# Japanese days of the week, from Monday to Sunday.
my $weekdays = '月火水木金土日';
my @weekdays = split '',$weekdays;
# Match a string for a weekday, like 月曜日 or (日)
# The long part (?=\W) is to stop it from accidentally matching a
# kanji which is part of a different word, like the following:
#平成二十年七月一日
#    日本論・日本人論は非常に面白いものだ。
my $match_weekday = '[（(]?(['.$weekdays.'])'.
    '(?:(?:(?:曜日|曜)[)\）])|[)\）]|(?=\W))';
# my $match_weekday = '[（(]?(['.$weekdays.'])(?:曜日|曜)?[)）]?';
# Match a day of the month, like 10日
my $match_dom = $jnumber.'\h*日';
# Match a month
my $match_month = $jnumber.'\h*月';
# Match jun
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
# 

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
my @months = qw/Invalid January February March April May June July
		August September October November December MM/;
my @days = qw/Invalid Monday Tuesday Wednesday Thursday Friday Saturday Sunday/;
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
    if (! $text) {
        return $text;
    }
    for my $datere (@jdatere) {
	my $regex = $$datere[0];
	my @process = split (/(?=[a-z][12]?)/, $$datere[1]);
        if ($verbose) {
            print "Looking for ",$$datere[1]," in ",$regex,"\n";
        }
	while ($text =~ /($regex)/g) {
	    my $date1;
	    my $date2;
	    my $orig = $1;
#	    print "Keys are ",$$datere[1],"\n";
	    my @matches = ($2,$3,$4,$5,$6,$7,$8,$9); # uh - oh. Be careful!
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
#		print $argdo,"\n";
		if ($argdo eq 'e') { # Era name in Japanese
		    $date1->{year} = $jera2w{$arg};
		} elsif ($argdo eq 'j') { # Japanese year
		    $date1->{year} += $arg;
		} elsif ($argdo eq 'y') {
		    $date1->{year} = $arg;
		} elsif ($argdo eq 'n') {
		    $date1->{year} += $arg;
		    $date1->{year} = "fiscal ".$date1->{year};
		} elsif ($argdo eq 'm' || $argdo eq 'm1') {
		    $date1->{month} = $arg;
		} elsif ($argdo eq 'd' || $argdo eq 'd1') {
		    $date1->{date} = $arg;
		} elsif ($argdo eq 'm2') {
		    $date2->{month} = $arg;
		} elsif ($argdo eq 'd2') {
		    $date2->{date} = $arg;
		} elsif ($argdo eq 'w' || $argdo eq 'w1') {
		    $date1->{wday} = $j2eweekday{$arg};
		} elsif ($argdo eq 'w2') {
#		    print "W2\n";
		    $date2->{wday} = $j2eweekday{$arg};
		} elsif ($argdo eq 'z') {
		    $date1->{jun} = $jun{$arg};
#		    print "\n*Jun of $arg is ",$date1->{jun},"\n";
		} elsif ($argdo eq 'x') {
                    if ($verbose) {
                        print "Dummy date '$orig'.\n" if $verbose;
                    }
		    $date1->{date}  = 32;
		    $date1->{month} = 13;
		}
	    }
	    my $edate;
	    if ($date2) {
		if ($callbacks &&
                    $callbacks->{make_date_interval}) {
		    $edate = &{$callbacks->{make_date_interval}} ($date1, $date2);
		}
                else {
		    $edate = make_date_interval ($date1, $date2);
		}
	    }
            else {
		if ($callbacks &&
                    $callbacks->{make_date}) {
		    $edate = &{$callbacks->{make_date}}($date1);
		}
                else {
		    $edate = make_date ($date1);
		}
	    }
            if ($verbose) {
                print "-> '$edate'\n" if $verbose;
            }
	    $text =~ s/\Q$orig\E/$edate/g;
	    if ($callbacks->{replace}) {
		&{$callbacks->{replace}}($callbacks->{data}, $orig, $edate);
	    }
	}
    }
    return $text;
}

1;

__END__

=encoding UTF-8

=head1 NAME

Lingua::JA::FindDates - scan text to find dates in a Japanese format

=head1 SYNOPSIS

  # Find and replace Japanese dates:

  use Lingua::JA::FindDates 'subsjdate';

  # Given a string, find and substitute all the Japanese dates in it.

  my $dates = '昭和４１年三月１６日';
  print subsjdate ($dates);

  # prints "March 16, 1966"

  # Find and substitute Japanese dates within a string:

  my $dates = 'blah blah blah 三月１６日';
  print subsjdate ($dates);

  # prints "blah blah blah March 16"

  # subsjdate can also call back a user-supplied routine each time a
  # date is found:

  sub replace_callback
  {
    my ($data, $before, $after) = @_;
    print "'$before' was replaced by '$after'.\n";
  }
  my $dates = '三月１６日';
  my $data = 'xyz'; # something to send to replace_callback
  subsjdate ($dates, {replace => \&replace_callback, data => $data});

  # prints "'三月１６日' was replaced by 'March 16'."

  # A routine can be used to format the date any way, letting C<subsjdate>
  # print it:

  sub my_date
  {
    my ($date) = @_;
    return join '/', $date->{month}."/".$date->{date};
  }
  my $dates = '三月１６日';
  print subsjdate ($dates, {make_date => \&my_date});

  # This prints "3/16"

=head1 DESCRIPTION

This module offers pattern matching of dates in the Japanese
language. Its main routine, L</subsjdate> scans a text and finds
things which appear to be Japanese dates.

The module recognizes the typical format of dates with the year first,
followed by the month, then the day, such as 平成20年七月十日
I<(Heisei nijūnen shichigatsu tōka)>. It also recognizes combinations
such as years alone, years and months, a month and day without a year,
fiscal years (年度, "nendo"), parts of the month, like 中旬 (chūjun,
the middle of the month), and periods between two dates.

It recognizes both the Japanese-style era-base year format, such as 
"平成２４年" (Heisei) for the current era, and European-style Christian
era year format, such as 2012年. It recognizes several forms of
numerals, including the ordinary ASCII numerals, 1, 2, 3; the "wide"
or "double width" numerals sometimes used in Japan, １, ２, ３; and
the kanji-based numeral system, 一, 二, 三. It recognizes some special
date formats such as 元年 for the first year of an era. It recognizes
era names identified by their initial letters, such as S41年 for Shōwa
41 (1966). It recognizes dates regardless of any spacing which might
be inserted between individual Japanese characters, such as 
"平 成 二 十 年 八 月".

The input text must be marked as Unicode, in other words character
data, not byte data.

The module has been tested on several hundred of documents, and it
should cope with all common Japanese dates. If you find that it cannot
identify some kind of date within Japanese text, please report that as
a bug.

If you would like to see more examples of how this module works, look
at the testing code in C<t/Lingua-JA-FindDates.t>.

=head1 FUNCTIONS

=head2 subsjdate

   my $translation = subsjdate ($text);

Translate Japanese dates into American dates. The first argument to
C<subsjdate> is a string like "平成２０年７月３日（木）". The routine
looks through the string to see if there is anything which appears to
be a Japanese date. If it finds one, it calls L</make_date> to make
the equivalent date in English (American-style), and then substitutes
it into C<$text>, as if performing the following type of operation:

   $text =~ s/平成２０年７月３日（木）/Thursday, July 3, 2008/g;

Users can supply a different date-making function using the second
argument. The second argument is a hash reference which may have the
following members:

=over

=item replace

    subsjdate ($text, {replace => \&my_replace, data => $my_data});
    # Now "my_replace" is called as
    # my_replace ($my_data, $before, $after);

If there is a replace value in the callbacks, subsjdate calls it as a
subroutine with the data in C<<$callbacks->{data}>> and the before and
after string, in other words the matched date and the string with
which it is to be replaced.

=item data

Any data you want to pass to L</replace>, above.

=item make_date

    subsjdate ($text, {make_date => \& mymakedate});

This is a replacement for the default L</make_date> function. The
default function turns the Japanese dates into American-style dates,
so, for example, "平成10年11月12日" is turned into "November 12,
1998". If you don't need to replace the default (if you want
American-style dates), you can leave this blank. If, for example, you
want dates in the form "Th 2008/7/3", you could write a routine like
the following:

   sub mymakedate
   {
       my ($date) = @_;
       return qw{Bad Mo Tu We Th Fr Sa Su}[$date->{wday}].
           $date->{year}.'/'.$date->{month}.'/'.$date->{date};
   } 

Your routine will be called in the same way as the default routine,
L</make_date>. It is necessary to check for the hash values for the
fields C<year>, C<month>, C<date>, and C<wday> being zero, since
L</subsjdate> matches "month/day" and "year/month" only dates.

=item make_date_interval

This is a replacement for the L<make_date_interval> function. 

  subsjdate ($text, {make_date_interval => \&mymakedateinterval});

Your routine will be called in the same way as the default routine,
L</make_date_interval>. Its arguments are two dates.

=back

=head1 DEFAULT CALLBACKS

This section describes the default callback routines.

=head2 make_date

   # Monday 19th March 2012.
   make_date ({
       year => 2012,
       month => 3,
       date => 19,
       wday => 1,
   })

C<make_date> is the default date-string-making routine. It turns the
date information supplied to it into a string representing the
date. C<make_date> is not exported.

L<subsjdate>, given a date like 平成２０年７月３日（木） (Heisei year
20, month 7, day 3, in other words "Thursday the third of July,
2008"), passes C<make_date> a hash reference with values (year =>2008,
month => 7, date => 3, wday => 4) for the year, month, date and day of
the week. C<make_date> returns a string, 'Thursday, July 3, 2008'. If
some fields of the date aren't defined, for example in the case of a
date like ７月３日 (3rd July), the hash values for the keys of the
unknown parts of the date, such as year or weekday, will be undefined.

To replace the default routine C<make_date> with a different format,
supply a C<make_date> callback to L<subsjdate>:

  sub my_date
  {
    my ($date) = @_;
    return join '/', $date->{month}."/".$date->{date};
  }
  my $dates = '三月１６日';
  print subsjdate ($dates, {make_date => \&my_date});

This prints

  3/16

=head2 make_date_interval

   make_date_interval (
   {
   # 19 February 2010
       year => 2010,
       month => 2,
       date => 19,
   },
   # Monday 19th March 2012.
   {
       year => 2012,
       month => 3,
       date => 19,
       wday => 1,
   },);

This function is called when an interval of two dates, such as 平成３年
７月２日〜９日, is detected. It makes a string to represent that
interval in English. It takes two arguments, hash references to the
first and second date. The hash references are in the same format as
L<make_date>.

This function is not exported. It is the default used by
C<subsjdate>. You can use another function instead of this default by
supplying a value C<make_date_interval> as a callback in L<subsjdate>.

=head1 BUGS

=over

=item １０月第４月曜日

"１０月第４月曜日", which means "the fourth Monday of October", comes
out as "October第April曜日".

=item 今年６月

The module does not handle things like 今年 (this year), 去年 (last
year), or 来年 (next year).

=item 末日

The module does not handle "末日" (matsujitsu) "the last day" (of a month).

=item 土日祝日

The module does not handle "土日祝日" (weekends and holidays).

=item 年末年始

The module does not handle "年末年始" (the new year period).

=item No sanity check of Japanese era dates

It does not detect that dates like 昭和百年 (Showa 100, an impossible
year, since Showa 63 (1988) was succeeded by Heisei 1 (1989)) are
invalid.

=item Only goes back to Meiji

The date matching only goes back to the Meiji era. There is
L<DateTime::Calendar::Japanese::Era> if you need to go back further.

=item Doesn't find dates in order

For those supplying their own callback routines, note that the dates
returned won't be in the order that they are in the text, but in the
order that they are found by the regular expressions, which means that
in a string with two dates, the callbacks might be called for the
second date before they are called for the first one. Basically the
longer forms of dates are searched for before the shorter ones.

=item UTF-8 version only

This module only understands Japanese encoded in Perl's internal form
(UTF-8).

=item Trips a bug in Perl 5.10

If you send subsjdate a string which is pure ASCII, you'll get a
stream of warning messages about "uninitialized value". The error
messages are wrong - this is actually a bug in Perl, reported as bug
number 56902
(L<http://rt.perl.org/rt3/Public/Bug/Display.html?id=56902>). But
sending this routine a string which is pure ASCII doesn't make sense
anyway, so don't worry too much about it.

=item Doesn't do 元日 (I<ganjitsu>)

This date (another way to write "1st January") is a little difficult,
since the characters which make it up could also occur in other
contexts, like 元日本軍 I<gennihongun>, "the former Japanese
military". Correctly parsing it requires a linguistic analysis of the
text, which this module isn't able to do.

=back

=cut

=head1 EXPORTS

This module exports one function, L<subsjdate>, on request.

=cut

=head1 SEE ALSO

These other modules might be more suitable for some purposes:

=over

=item L<DateTime::Locale::JA>

Minimal selection of Japanese date functions. It's not complete enough
to deal with the full range of dates in actual documents.

=item L<DateTime::Format::Japanese>

This parses Japanese dates. Unlike the present module it claims to
also format them, so it can turn a L<DateTime> object into a Japanese
date, and it also does times. 

=item L<Lingua::JA::Numbers>

Kanji / numeral convertors. It converts numbers including decimal
points and numbers into the billions and trillions.

=item L<DateTime::Calendar::Japanese::Era>

A full set of Japanese eras.

=back

=head1 AUTHOR

Ben Bullock, <bkb@cpan.org>

=cut

=head1 COPYRIGHT AND LICENCE

Copyright (C) 2010-2012 Ben Bullock.

You may use, copy, distribute, and modify this module under the same
terms as the Perl programming language.

=cut

