#!/usr/local/bin/perl

# $Id: wsd.pl,v 1.2 2005/04/13 00:00:16 jmichelizzi Exp $

use strict;
use warnings;

use WordNet::SenseRelate::AllWords;
use WordNet::QueryData;
use Getopt::Long;

our $measure = 'WordNet::Similarity::lesk';
our $mconfig;
our $contextf;
our $compfile;
our $stoplist;
our $window = 3;
our $contextScore = 0;
our $pairScore = 0;
our $silent;
our $trace;
our $help;
our $version;
our $scheme = 'normal';
our $outfile;
our $forcepos;

our $format; # raw|tagged|parsed

my $ok = GetOptions ('type|measure=s' => \$measure,
		     'config=s' => \$mconfig,
		     'context=s' => \$contextf,
		     'compounds=s' => \$compfile,
		     'stoplist=s' => \$stoplist,
		     'window=i' => \$window,
		     'pairScore=f' => \$pairScore,
		     'contextScore=f' => \$contextScore,
		     'scheme=s' => \$scheme,
		     forcepos => \$forcepos,
		     silent => \$silent,
		     'trace=i' => \$trace,
		     help => \$help,
		     version => \$version,
		     'outfile=s' => \$outfile,
		     'format=s' => \$format,
		     );
$ok or exit 1;

if ($help) {
    showUsage ("Long");
    exit;
}

if ($version) {
    print "wsd.pl version 0.04\n";
    print "Copyright (C) 2004-2005, Jason Michelizzi and Ted Pedersen\n\n";
    print "This is free software, and you are welcome to redistribute it\n";
    print "under certain conditions.  This software comes with ABSOLUTELY\n";
    print "NO WARRANTY.  See the file COPYING or run 'perldoc perlgpl' for\n";
    print "more information.\n";
    exit;
}

unless (defined $contextf) {
    print STDERR "The --context argument is required. This is the text to be disambiguated\n";
    showUsage ();
    exit 1;
}

unless ($format
        and (($format eq 'raw') or ($format eq 'parsed') or ($format eq 'tagged'))) {
    print STDERR "The --format argument is required. This is the type of text to be disambiguated.\n";
    showUsage ();
    exit 1;
}

#my $istagged = isTagged ($contextf);
my $istagged = $format eq 'tagged' ? 1 : 0;

unless ($silent) {
    print "Current configuration:\n";
    print "    context file  : $contextf\n";
    print "    format        : $format\n";
    print "    scheme        : $scheme\n";
    print "    tagged text   : ", ($istagged ? "yes" : "no"), "\n";

    if ($scheme eq 'normal') {
	# these items are only relevent to normal mode (not sense1 or random)
	print "    measure       : $measure\n";
	print "    window        : ", $window, "\n";
	print "    contextScore  : ", $contextScore, "\n";
	print "    pairScore     : ", $pairScore, "\n";
	print "    measure config: ", ($mconfig ? $mconfig : '(none)'), "\n";
	print "    trace         : ", ($trace ? $trace : "no"), "\n";
	print "    forcepos      : ", ($forcepos ? "yes" : "no"), "\n";
    }

    print "    compound file : ", ($compfile ? $compfile : '(none)'), "\n";
    print "    stoplist      : ", ($stoplist ? $stoplist : '(none)') , "\n";
}

local $| = 1;
print "Loading WordNet... " unless $silent;
my $qd = WordNet::QueryData->new;
print "done.\n" unless $silent;

# options for the WordNet::SenseRelate constructor
my %options = (wordnet => $qd,
	       measure => $measure,
	       );
$options{config} = $mconfig if defined $mconfig;
$options{compfile} = $compfile if defined $compfile;
$options{stoplist} = $stoplist if defined $stoplist;
$options{trace} = $trace if defined $trace;
$options{pairScore} = $pairScore if defined $pairScore;
$options{contextScore} = $contextScore if defined $contextScore;
$options{outfile} = $outfile if defined $outfile;
$options{forcepos} = $forcepos if defined $forcepos;

my $sr = WordNet::SenseRelate::AllWords->new (%options);


open (FH, '<', $contextf) or die "Cannot open '$contextf': $!";

my @sentences;
if ($format eq 'raw') {
    local $/ = undef;
    my $input = <FH>;
    $input =~ tr/\n/ /;


    @sentences = splitSentences ($input);
    undef $input;
    foreach my $sent (@sentences) {
	$sent = cleanLine ($sent);
    }
}
else {
    @sentences = <FH>;
}

close FH;
my $i = 0;
foreach my $sentence (@sentences) {
    my @context = split /\s+/, $sentence;
    next unless scalar @context > 0;
    pop @context while !defined $context[$#context];
	
    my @res = $sr->disambiguate (window => $window,
				 tagged => $istagged,
				 scheme => $scheme,
				 context => [@context]);

    print STDOUT join (' ', @res), "\n";

    if ($trace) {
	my $tstr = $sr->getTrace ();
	print $tstr, "\n";
    }
}

exit;

sub isTagged
{
    my $file = shift;
    open FH, '<', $file or die "Cannot open context file '$file': $!";
    my @words;
    while (my $line = <FH>) {
	chomp $line;
	push @words, split (/\s+/, $line);
	last if $#words > 20;
    }
    close FH;

    my $tag_count = 0;
    foreach my $word (@words) {
	$tag_count++ if $word =~ m|/\S|;
    }
    my $ratio = $tag_count / scalar @words;

    # we consider the corpus to be tagged if we found that 70% or more
    # of the first 20 words were tagged (70% is somewhat of an arbitrary
    # value).
    return 1 if $ratio > 0.7;
    return 0;
}

sub cleanLine
{
    my $line = shift;
    # remove commas, colons, semicolons
    $line =~ s/[,:;]+/ /g;
    return $line;
}

# The sentence boundary algorithm used here is based on one described
# by C. Manning and H. Schutze. 2000. Foundations of Statistical Natural
# Language Processing. MIT Press: 134-135.
sub splitSentences
{
    my $string = shift;
    return unless $string;

    # abbreviations that (almost) never occur at the end of a sentence
    my @known_abbr = qw/prof Prof ph d Ph D dr Dr mr Mr mrs Mrs ms Ms vs/;

    # abbreviations that can occur at the end of sentence
    my @sometimes_abbr = qw/etc jr Jr sr Sr/;


    my $pbm = '<pbound/>'; # putative boundary marker

    # put a putative sent. boundary marker after all .?!
    $string =~ s/([.?!])/$1$pbm/g;

    # move the boundary after quotation marks
    $string =~ s/$pbm"/"$pbm/g;
    $string =~ s/$pbm'/'$pbm/g;

    # remove boundaries after certain abbreviations
    foreach my $abbr (@known_abbr) {
	$string =~ s/\b$abbr(\W*)$pbm/$abbr$1 /g;
    }

    foreach my $abbr (@sometimes_abbr) {
	$string =~ s/$abbr(\W*)\Q$pbm\E\s*([a-z])/$abbr$1 $2/g;
    }

    # remove !? boundaries if not followed by uc letter
    $string =~ s/([!?])\s*$pbm\s*([a-z])/$1 $2/g;


    # all remaining boundaries are real boundaries
    my @sentences = map {s/^\s+|\s+$//g; $_} split /[.?!]\Q$pbm\E/, $string;
}

sub showUsage
{
    my $long = shift;
    print "Usage: wsd.pl --context FILE --format FORMAT [--scheme SCHEME]\n";
    print "              [--type MEASURE] [--config FILE] [--compounds FILE]\n";
    print "              [--stoplist file] [--window INT] [--contextScore NUM]\n";
    print "              [--pairScore NUM] [--outfile FILE] [--trace INT] [--silent]\n";
    print "              | {--help | --version}\n";

    if ($long) {
	print "Options:\n";
	print "\t--context FILE       a file containing the text to be disambiguated\n";
	print "\t--format FORMAT      type of --context ('raw', 'parsed', or 'tagged')\n";
	print "\t--scheme SCHEME      disambiguation scheme to use.\n";
	print "\t                       ('normal', 'sense1', or 'random')\n";
	print "\t--type MEASURE       the relatedness measure to use\n";
	print "\t--config FILE        a configuration file for the relatedness measure\n";
	print "\t--compounds FILE     a file of compound words known to WordNet\n";
	print "\t--stoplist FILE      a file of regular expressions that define\n";
	print "\t                       the words to be excluded from --context\n";
	print "\t--window INT         include INT WordNet words to the left\n";  	
	print "\t                       AND right in the window of context\n"; 
	print "\t--contextScore NUM   the  minimum required of a winning score\n";
	print "\t                       to assign a sense to a target word\n";
	print "\t--pairScore NUM      the minimum pairwise threshold when\n";
	print "\t                       measuring target and word in window\n";
	print "\t--outfile FILE       create a file with one word-sense per line\n";
	print "\t--trace INT          set trace levels. greater values show more\n";
	print "\t                       detail. may be summed to combine output. \n";
	print "\t--silent             run silently; shows only final output\n";
        print "\t--forcepos           force all words in window of context\n";
        print "\t                       to be same pos as target (pos coercion)\n";
	print "\t--help               show this help message\n";
	print "\t--version            show version information\n";
    }
}

__END__

=head1 NAME

wsd.pl - disambiguate words

=head1 SYNOPSIS

wsd.pl --context FILE --format FORMAT [--scheme SCHEME] [--type MEASURE] [--config FILE] [--compounds FILE] [--stoplist FILE] [--window INT] [--contextScore NUM] [--pairScore NUM] [--outfile FILE] [--trace INT] [--silent] [--forcepos] | --help | --version

=head1 DESCRIPTION

Disambiguates each word in the context file using the specified relatedness
measure (or WordNet::Similarity::lesk if none is specified).

=head1 OPTIONS

N.B., the I<=> sign between the option name and the option parameter is
optional.

=over

=item --context=B<FILE>

The input file containing the text to be disambiguated.  This
"option" is required.

=item --format=B<FORMAT>

The format of the input file.  Valid values are

=over

=item raw

The input is raw text.  Sentence boundary detection will be performed, and
all punctuation will be removed.

=item parsed

The input is untagged text with one sentence per line and all unwanted
punctuation has already been removed.  Note: many WordNet terms contain
punctuation, such as I<U.S.>, I<Alzheimer's>, I<S/N>, etc.

=item tagged 

Similar to parsed, but the input text has been part-of-speech tagged with
Penn Treebank tags (perhaps using the Brill tagger).

=back

=item --scheme=B<SCHEME>

The disambiguation scheme to use.  Valid values are "normal", "sense1", 
and "random". The default is "normal".  WordNet sense 1 disambiguation  
guesses that the correct sense for each word is the first sense in WordNet  
because the senses of words in WordNet are ranked according to frequency.   
The first sense is more likely than the second, the second is more likely  
than the third, etc. Random selects one of the possible senses of the 
target word randomly. 

=item --measure=B<MEAURE>

The relatedness measure to be used.  The default is WordNet::Similarity::lesk.

=item --config=B<FILE>

The name of a configuration file for the specified relatedness measure.

=item --compounds=B<FILE>

A file containing compound words.

=item --stoplist=B<FILE>

A file containing regular expressions (as understood by Perl), surrounded by
by slashes (e.g. /\d+/ removes any word containing a digit [0-9]).  Any word
in the text to be disambiguated that matches one of the regular  
expressions in the file is removed.  Each regular expression must be on  
its own line, and any trailing whitespace is ignored.

Care must be taken when crafting a stoplist.  For example, it is tempting
to use /a/ to remove the word 'a', but that expression would result in
all words containing the lowercase letter a to be removed.  A better
alternative would be /\ba\b/.

=item --window=B<INTEGER>

Defines the size of the window of context. The default value is 3, which 
means that 3 words to the left, and 3 words to the right are used by the 
algorithm. Note that stop words and words not known to WordNet are 
excluded from the window of context prior to determining the size, so the  
window is always made up of WordNet words. 

=item --contextScore=B<REAL>

If no sense of the target word achieves this minimum score, then
no winner will be projected (e.g., it is assumed that there is
no best sense or that none of the senses are sufficiently related
to the surrounding context).  The default is zero.

=item --pairScore=B<REAL>

The minimum pairwise score between a sense of the target word and
the best sense of a context word that will be used in computing
the overall score for that sense of the target word.  Setting this
to be greater than zero (but not too large) will reduce noise.
The default is zero.

=item --outfile=B<FILE>

The name of a file to which output should be sent. This file will display 
one word and its sense per line.  

=item --trace=B<INT>

Turn tracing on/off.  A value of zero turns tracing off, a non-zero value
turns tracing on.  The different trace levels can be added together
to see the combined traces.  The trace levels are:

=over

=item 1

Show the context window for each pass through the algorithm.

=item 2

Display the winning score for each pass (i.e., for each target word). 

=item 4

Display the non-zero scores for each sense of each target word (overrides 2).

=item 8

Display the non-zero values from the semantic relatedness measures.

=item 16

Show the zero values as well when combined with either 4 or 8.  When not
used with 4 or 8, this has no effect.

=item 32

Display traces from the semantic relatedness module.

=back

=item --silent

Silent mode.  No information about progress, etc. is printed.  Just the
final output.

=item --forcepos

Turn part of speech coercion on.  POS coercion forces other words in the
context window to be of the same part of speech as the target word.  This
may be useful when using a measure of semantic similarity that only works
with noun-noun and verb-verb pairs.

=back

=head1 AUTHORS

Jason Michelizzi, E<lt>jmichelizzi at users.sourceforge.netE<gt>

Ted Pedersen, E<lt>tpederse at d.umn.eduE<gt>

=head1 BUGS

None known.

=head1 COPYRIGHT

Copyright (C) 2004-2005 Jason Michelizzi and Ted Pedersen

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

=cut
