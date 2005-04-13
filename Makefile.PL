# $Id: Makefile.PL,v 1.2 2005/04/13 00:00:16 jmichelizzi Exp $

use strict;
use warnings;
use 5.006;
use ExtUtils::MakeMaker;

#

WriteMakefile(
    NAME              => 'WordNet::SenseRelate::AllWords',
    VERSION_FROM      => 'lib/WordNet/SenseRelate/AllWords.pm', # finds $VERSION
    PREREQ_PM         => {'WordNet::QueryData' => 1.37,
			  'WordNet::Similarity' => 0.08},
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/WordNet/SenseRelate/AllWords.pm', # retrieve abstract from module
       AUTHOR         => 'Jason Michelizzi <jmichelizzi at users.sourceforge.net>') : ()),
    EXE_FILES         => ['utils/wsd.pl'],
);
