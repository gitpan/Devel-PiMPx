use strict;
use warnings;
use Module::Build;

sub YES { 1 };
sub NO  { 0 };

my $builder = Module::Build->new(
    module_name          => 'Devel::PiMPx',
    license              => 'perl',
    dist_author          => 'Ask Solem <ASKSH@cpan.org>',
    dist_version_from    => 'lib/Devel/PiMPx.pm',
    all_from             => 'lib/Devel/PiMPx.pm',
    dist_abstract        => 'The Perl-inclusive Macro Processor.',
    dynamic_config       => NO,
    sign                 => NO, # asksh: have to find out why my signature fails.
    recursive_test_files => YES,
    build_requires       => {
        'Test::More'            => 0.42,
    },
    pod_files            => {
    },
    add_to_cleanup       => [ qw(
        a.out
        test.pl
        test.c
        test.cpp
        test.m
        *.swp
        .gdb_history
        install.cache
        t/cache
    ) ],
);

$builder->create_build_script( );

