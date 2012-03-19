use strict;
use warnings;
use ExtUtils::MakeMaker;

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
