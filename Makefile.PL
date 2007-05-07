use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Devel::PiMPx',
	'EXE_FILES'	=> [ 'bin/pimpx' ],
    'VERSION_FROM'	=> 'lib/Devel/PiMPx.pm', # finds $VERSION
    'PREREQ_PM'		=> {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'lib/Devel/PiMPx.pm', # retrieve abstract from module
       AUTHOR     => 'Ask Solem <ask@0x61736b.net>') : ()),
);
