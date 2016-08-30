use warnings;
use strict;
use utf8;
use FindBin '$Bin';
use Test::More;
my $builder = Test::More->builder;
binmode $builder->output,         ":utf8";
binmode $builder->failure_output, ":utf8";
binmode $builder->todo_output,    ":utf8";
binmode STDOUT, ":encoding(utf8)";
binmode STDERR, ":encoding(utf8)";
use Perl::Build::Pod qw/pod_checker pod_link_checker/;
my $filepath = "$Bin/../lib/Lingua/JA/FindDates.pod";
my $errors = pod_checker ($filepath);
ok (@$errors == 0, "No errors");
my $linkerrors = pod_link_checker ($filepath);
ok (@$linkerrors == 0, "No link errors");
if (@$linkerrors > 0) {
    for (@$linkerrors) {
	print "$_\n";
    }
}
done_testing ();
