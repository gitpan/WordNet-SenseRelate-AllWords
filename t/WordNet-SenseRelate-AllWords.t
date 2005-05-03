# $Id: WordNet-SenseRelate-AllWords.t,v 1.5 2005/04/30 15:20:52 jmichelizzi Exp $

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl WordNet-SenseRelate.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 19;
BEGIN {use_ok WordNet::SenseRelate::AllWords}
BEGIN {use_ok WordNet::QueryData}

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $qd = WordNet::QueryData->new;
ok ($qd);

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



