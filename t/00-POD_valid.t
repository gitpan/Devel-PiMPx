#!/usr/local/bin/perl
# $Id: 00-POD_valid.t,v 1.1 2007/05/07 12:46:21 ask Exp $
# $Source: /opt/CVS/pimpx/t/00-POD_valid.t,v $
# $Author: ask $
# $HeadURL$
# $Revision: 1.1 $
# $Date: 2007/05/07 12:46:21 $
use strict;
use warnings;
use Test::More;
use English qw( -no_match_vars );
use vars qw($VERSION);
$VERSION = 1.1;
eval "use Test::Pod 1.00"; ## no critic
if ($EVAL_ERROR) {
    plan skip_all => 'Test::Pod 1.00 required for testing POD';
}
all_pod_files_ok( );
