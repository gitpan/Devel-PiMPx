# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 5 };
use Devel::PiMPx;
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

my @testfiles = qw(tests/define.pmpx tests/print.pmpx tests/if.pmpx);
my $pp = new Devel::PiMPx(programname=>$0);
ok(1);

for(my $i = 0; $i <= $#testfiles; $i++)
{
	if($i % 2) {
		$pp->no_lineno(1);
		$pp->debug(0);
	} else {
		$pp->no_lineno(0);
		$pp->debug(1);
	}
	ok($pp->preprocess($testfiles[$i]));
}
