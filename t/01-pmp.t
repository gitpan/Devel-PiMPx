# $Id: 01-pmp.t,v 1.2 2007/05/07 12:46:21 ask Exp $
# $Source: /opt/CVS/pimpx/t/01-pmp.t,v $
# $Author: ask $
# $HeadURL$
# $Revision: 1.2 $
# $Date: 2007/05/07 12:46:21 $
use strict;
use warnings;
my $THIS_TEST_HAS_TESTS = 5;

use Test::More;
use File::Spec::Functions;
use FindBin;
plan( tests => $THIS_TEST_HAS_TESTS );
use_ok('Devel::PiMPx', 'use Devel::PiMPx');

#########################

my $bin_dir = $FindBin::Bin;

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

my @testfiles = qw(tests/define.pmpx tests/print.pmpx tests/if.pmpx);
my $pp = new Devel::PiMPx(programname=>$0);
ok($pp, 'create new pmp object.');
$pp->no_lineno(1);
$pp->debug(0);

for (my $i = 0; $i <= $#testfiles; $i++) {
    my $this_testfile = catfile($bin_dir, $testfiles[$i]);
	if ($i % 2) {
		#$pp->no_lineno(1);
		#$pp->debug(0);
	}
    else {
		#$pp->no_lineno(0);
		#$pp->debug(1);
	}
	ok($pp->preprocess($this_testfile), "preprocess $testfiles[$i]");
}
