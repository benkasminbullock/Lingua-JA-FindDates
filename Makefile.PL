use strict;
use warnings;
use ExtUtils::MakeMaker;

# Module requires Perl 5.10 or above.

if ($] < 5.010) {
    exit;
}

my $pm = 'lib/Lingua/JA/FindDates.pm';

WriteMakefile (
    NAME => 'Lingua::JA::FindDates',
    VERSION_FROM => $pm,
    ABSTRACT_FROM => $pm,
    LICENSE => 'perl',
    AUTHOR => 'Ben Bullock <bkb@cpan.org>',
    EXE_FILES => [
        'script/subsjdate',
    ],
);
