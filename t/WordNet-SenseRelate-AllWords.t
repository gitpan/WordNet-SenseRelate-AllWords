
# $Id: WordNet-SenseRelate-AllWords.t,v 1.10 2008/03/20 05:37:39 tpederse Exp $

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl WordNet-SenseRelate.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 30;
BEGIN {use_ok WordNet::SenseRelate::AllWords}
BEGIN {use_ok WordNet::QueryData}

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $qd = WordNet::QueryData->new;
ok ($qd);

# find out what version of wordnet we are using for version specific tests

my $wnver = '0.0';
$wnver = $qd->version() if($qd->can('version'));

# 

my @context = ('my/PRP$', 'cat/NN', 'is/VBZ', 'a/DT', 'wise/JJ', 'cat/NN');

my $obj = WordNet::SenseRelate::AllWords->new (wordnet => $qd,
				     measure => 'WordNet::Similarity::lesk',
				     pairScore => 1,
				     contextScore => 1);
ok ($obj);

my @res = $obj->disambiguate (window => 5,
			      tagged => 1,
			      context => [@context]);

no warnings 'qw';
my @expected = qw/my cat#n#7 be#v#1 a wise#a#1 cat#n#7/;

is ($#res, $#expected);

for my $i (0..$#expected) {
	is ($res[$i], $expected[$i]);
}

undef $obj;

# try it with tracing on
$obj = WordNet::SenseRelate::AllWords->new (wordnet => $qd,
				  measure => 'WordNet::Similarity::lesk',
				  trace => 1,
				  );

ok ($obj);

undef @res;

@res = $obj->disambiguate (window => 2,
			   tagged => 1,
			   context => [@context]);

my $str = $obj->getTrace ();

ok ($str);

@expected = qw/my cat#n#1 be#v#1 a wise#a#1 cat#n#7/;

for my $i (0..$#expected) {
	is ($res[$i], $expected[$i]);
}


# check that physics#n stays as physics#n not physic#n in wnformat mode

@context = qw/physics#n not#r medicine#n/;
@expected = qw/physics#n#1 not#r#1 medicine#n#2/;

$obj = $obj->new (wordnet => $qd,
                  measure => 'WordNet::Similarity::lesk',
                  wnformat => 1);

@res = $obj->disambiguate (window => 3, tagged => 0, context => [@context]);

for my $i (0..$#expected) {
    is ($res[$i], $expected[$i]);
}


# test fixed mode
@context = qw/brick building fire burn/;

# this test case changes results with version 3.0 of WordNet
# this is what is expected prior to 3.0

@expected = qw/brick#n#1 building#n#1 fire#n#3 burn#n#3/;

# in 3.0 it shifts to fire#n#2, which is what we have here
# if we see that this is 3.0 we'll change the above:

 if($wnver eq '3.0') {
   @expected =qw/brick#n#1 building#n#1 fire#n#2 burn#n#3/;
  }

$obj = $obj->new (wordnet => $qd,
		  measure => 'WordNet::Similarity::lesk');

@res = $obj->disambiguate (window => 4, tagged => 0,
                           scheme => 'fixed', context => [@context]);

for my $i (0..$#expected) {
    is ($res[$i], $expected[$i]);
}

# create a test case to make sure that we don't explode if window size 
# is omitted - the only required parameter should be context, fixes
# bug reported for 0.07 

@context = qw/winter spring summer fall/;

@expected = qw/winter#n#1 spring#n#1 summer#n#1 fall#n#1/;

$obj = $obj->new (wordnet => $qd,
		  measure => 'WordNet::Similarity::lesk');

@res = $obj->disambiguate (context => [@context]);

for my $i (0..$#expected) {
    is ($res[$i], $expected[$i]);
}

