# $Id: Makefile.PL,v 1.3 2008/03/14 01:49:08 tpederse Exp $

use strict;
use warnings;
use 5.006;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'WordNet::SenseRelate::AllWords',
    VERSION_FROM      => 'lib/WordNet/SenseRelate/AllWords.pm', # finds $VERSION
    PREREQ_PM         => {'WordNet::Similarity' => 0.16},
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/WordNet/SenseRelate/AllWords.pm', # retrieve abstract from module
       AUTHOR         => 'Ted Pedersen <tpederse at d.umn.edu>') : ()),
    EXE_FILES         => ['utils/wsd.pl'],
);
