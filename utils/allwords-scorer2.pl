#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;

my %nounhash;
my %verbhash;
my %adjhash;
my %advhash;
my %ans;
my $instances=0;
my $skipped=0;
my $diffword=0;
my $global_score=0;
my $diffpos=0;
my $ansf;
my $keyf;
my $help;
my $version;

my $ok = GetOptions (
		     'ansfile=s' => \$ansf,
		     'keyfile=s' => \$keyf,
		     help => \$help,
		     version => \$version,
		     );
$ok or exit 1;

if ($help) {
    showUsage ("Long");
    exit;
}

if ($version) {
    print "allwords-scorer2.pl - allwords scorer2 perl program\n";
    print 'Last modified by : $Id: allwords-scorer2.pl,v 1.2 2009/02/11 02:50:33 kvarada Exp $';
    print "\n";
    exit;
}

unless (defined $ansf && defined $ansf ) {
    showUsage();
    exit 1;
}

open (KFH, '<', $keyf) or die "Cannot open '$keyf': $!";
my(@key) = <KFH>;
close KFH;

open (AFH, '<', $ansf) or die "Cannot open '$ansf': $!";
while(<AFH>)
{
  chomp;
  my ($w,$p,$aid,$s)=(/(\S+).([a|n|r|v]) (\d+) (\d+)/);
  $ans{$aid}=$w." ".$p." ".$s; 
}
close AFH;

initializeHashes();

foreach my $k (@key)
{
	my ($word,$pos,$kid,$sense)=($k =~ /(\S+).([a|n|r|v]) (\d+) (\d+)/);
	$instances++;
	if(!defined $ans{$kid})
	{
		$skipped++;
		if($pos eq "n"){
			$nounhash{skipped}+=1;
		}elsif($pos eq "v"){
			$verbhash{skipped}+=1;
		}elsif($pos eq "a"){
			$adjhash{skipped}+=1;
		}elsif($pos eq "r"){
			$advhash{skipped}+=1;
		}
		next;
	}
		
	my ($aword,$apos,$asense)=($ans{$kid} =~ /(\S+) ([a|r|v|n]) (\d+)/) if(defined $ans{$kid});

	if($word ne $aword){
		$diffword++;
		$skipped++;
		if($pos eq "n"){
			$nounhash{skipped}+=1;
		}elsif($pos eq "v"){
			$verbhash{skipped}+=1;
		}elsif($pos eq "a"){
			$adjhash{skipped}+=1;
		}elsif($pos eq "r"){
			$advhash{skipped}+=1;
		}		
		next;
	}	
	
	if($pos eq "n"){
		$nounhash{attempted}+=1;
	}elsif($pos eq "v"){
		$verbhash{attempted}+=1;
	}elsif($pos eq "a"){
		$adjhash{attempted}+=1;
	}elsif($pos eq "r"){
		$advhash{attempted}+=1;
	}
	
	if($pos eq "n"){
		if($pos eq $apos){
				$nounhash{asnoun}+=1;
				if($sense eq $asense){
					$global_score++;		
					$nounhash{correct}+=1;
				}else{
					$nounhash{wrong}+=1;	
				}
		}else{
			$diffpos++;
			$nounhash{asverb}+=1 if ($apos eq "v");
			$nounhash{asadj}+=1 if ($apos eq "a");
			$nounhash{asadv}+=1 if ($apos eq "r");
		}
	}elsif($pos eq "v"){
		if($pos eq $apos){
				$verbhash{asverb}+=1;
				if($sense eq $asense){
					$global_score++;		
					$verbhash{correct}+=1;
				}else{
					$verbhash{wrong}+=1;	
				}
		}else{
			$diffpos++;
			$verbhash{asnoun}+=1 if ($apos eq "n");
			$verbhash{asadj}+=1 if ($apos eq "a");
			$verbhash{asadv}+=1 if ($apos eq "r");
		}
	}elsif($pos eq "a"){
		if($pos eq $apos){
				$adjhash{asadj}+=1;
				if($sense eq $asense){
					$global_score++;		
					$adjhash{correct}+=1;
				}else{
					$adjhash{wrong}+=1;	
				}
		}else{
			$diffpos++;
			$adjhash{asnoun}+=1 if ($apos eq "n");
			$adjhash{asverb}+=1 if ($apos eq "v");
			$adjhash{asadv}+=1 if ($apos eq "r");
		}
	}elsif($pos eq "r"){
		if($pos eq $apos){
				$advhash{asadv}+=1;
				if($sense eq $asense){
					$global_score++;		
					$advhash{correct}+=1;
				}else{
					$advhash{wrong}+=1;	
				}
		}else{
			$diffpos++;
			$advhash{asnoun}+=1 if ($apos eq "n");
			$advhash{asverb}+=1 if ($apos eq "v");
			$advhash{asadj}+=1 if ($apos eq "a");
		}
	}

}#foreach end

my $precision;
my $recall;
my $fmeasure;

my $instances_attempted=$instances - $skipped;
eval{$precision=$global_score / $instances_attempted;};
$precision=0 if($@);
eval{$recall=$global_score / $instances;};
$recall=0 if($@);
print "\nscore for \"$ansf\" using key \"$keyf\" :";
printf "\n precision: %.3f", $precision;
print " ($global_score correct of $instances_attempted attempted.)";
printf "\n recall: %.3f",$recall; 
print " ($global_score correct of $instances in total)";
eval{$fmeasure = 2 * $precision * $recall / ($precision + $recall);};
$fmeasure = 0 if($@);
printf "\n F-measure: %.3f",$fmeasure; 

printf	"\n\n attempted: %.2f%%",(100.0 * ($instances_attempted / $instances));
print "($ instances_attempted attempted of $instances in total)";
printf "\n part of speech tag mismatch in attempted instances: %0.2f%%", (100.0 * ($diffpos / $instances_attempted));
print " ($diffpos mismatches of $instances_attempted attempted instances)";
printf "\n skipped instances : %0.2f%%", (100.0 * ($skipped / $instances));
print " (skipped $skipped instances of total $instances instances";
print " because the instance id or the word was not found in the answer file)";


print "\n\nNouns:";
eval{$precision=($nounhash{correct}/$nounhash{attempted});};
$precision=0 if($@);
eval{$recall=($nounhash{correct}/($nounhash{attempted}+$nounhash{skipped}));};
$recall=0 if($@);
printf "\n Precision : %0.3f",$precision;
print " (", $nounhash{correct}, " correct of $nounhash{attempted} nouns attempted.)";
printf "\n Recall : %0.3f",$recall;
print " (", $nounhash{correct}, " correct of ",$nounhash{attempted}+$nounhash{skipped}, " noun instances in total)";
eval{$fmeasure = 2 * $precision * $recall / ($precision + $recall)};
$fmeasure = 0 if($@);
printf "\n F-measure: %.3f",$fmeasure; 

print "\n\nVerbs:";
eval{$precision=($verbhash{correct}/$verbhash{attempted});};
$precision=0 if($@);
eval{$recall=($verbhash{correct}/($verbhash{attempted}+$verbhash{skipped}));};
$recall=0 if($@);
printf "\n Precision : %0.3f", $precision;
print " (", $verbhash{correct}, " correct of $verbhash{attempted} verbs attempted.)";
printf "\n Recall : %0.3f", $recall;
print " (", $verbhash{correct}, " correct of ",$verbhash{attempted}+$verbhash{skipped}, " verb instances in total)";
eval{$fmeasure = 2 * $precision * $recall / ($precision + $recall);};
$fmeasure = 0 if($@);
printf "\n F-measure: %.3f",$fmeasure; 

print "\n\nAdjectives:";
eval{$precision=($adjhash{correct}/$adjhash{attempted});};
$precision=0 if($@);
eval{$recall=($adjhash{correct}/($adjhash{attempted}+$adjhash{skipped}));};
$recall=0 if($@);
printf "\n Precision : %0.3f", $precision;
print " (", $adjhash{correct}, " correct of $adjhash{attempted} adjectives attempted.)";
printf "\n Recall : %0.3f", $recall;
print " (", $adjhash{correct}, " correct of ",$adjhash{attempted}+$adjhash{skipped}, " adjective instances in total)";
eval{$fmeasure = 2 * $precision * $recall / ($precision + $recall);};
$fmeasure = 0 if($@);
printf "\n F-measure: %.3f",$fmeasure; 

print "\n\nAdjverbs:";
eval{$precision=($advhash{correct}/$advhash{attempted});};
$precision=0 if($@);
eval{$recall=($advhash{correct}/($advhash{attempted}+$advhash{skipped}));};
$recall=0 if($@);
printf "\n Precision : %0.3f", $precision;
print " (", $advhash{correct}, " correct of $advhash{attempted} adverbs attempted.)";
printf "\n Recall : %0.3f", $recall;
print " (", $advhash{correct}, " correct of ",$advhash{attempted}+$advhash{skipped}, " adverb instances in total)";
eval{$fmeasure = 2 * $precision * $recall / ($precision + $recall);};
$fmeasure = 0 if($@);
printf "\n F-measure: %.3f",$fmeasure; 


print "\n\n Confusion Matrix for part of speech tags :\n\n";
print " \t\tNoun\t\tVerb\t\tAdj\t\tAdv\t\t| Key\n";
print " Noun\t\t$nounhash{asnoun}\t\t$nounhash{asverb}\t\t$nounhash{asadj}\t\t$nounhash{asadv}\t\t| $nounhash{attempted}\n";
print " Verb\t\t$verbhash{asnoun}\t\t$verbhash{asverb}\t\t$verbhash{asadj}\t\t$verbhash{asadv}\t\t| $verbhash{attempted}\n";
print " Adj\t\t$adjhash{asnoun}\t\t$adjhash{asverb}\t\t$adjhash{asadj}\t\t$adjhash{asadv}\t\t| $adjhash{attempted}\n";
print " Adv\t\t$advhash{asnoun}\t\t$advhash{asverb}\t\t$advhash{asadj}\t\t$advhash{asadv}\t\t| $advhash{attempted}\n";

$nounhash{total}=$nounhash{asnoun}+$verbhash{asnoun}+$adjhash{asnoun}+$advhash{asnoun};
$verbhash{total}=$nounhash{asverb}+$verbhash{asverb}+$adjhash{asverb}+$advhash{asverb};
$adjhash{total}=$nounhash{asadj}+$verbhash{asadj}+$adjhash{asadj}+$advhash{asadj};
$advhash{total}=$nounhash{asadv}+$verbhash{asadv}+$adjhash{asadv}+$advhash{asadv};
my $total=$nounhash{total}+$verbhash{total}+$adjhash{total}+$advhash{total};
print "--------------------------------------------------------------------------------|-------\n";
print " Ans\t\t$nounhash{total}\t\t$verbhash{total}\t\t$adjhash{total}\t\t$advhash{asadv}\t\t| $total\n\n";



sub initializeHashes
{
	$nounhash{total}=0;
	$nounhash{attempted}=0;
	$nounhash{correct}=0;
	$nounhash{wrong}=0;
	$nounhash{skipped}=0;
	$nounhash{asnoun}=0;
	$nounhash{asverb}=0;
	$nounhash{asadj}=0;
	$nounhash{asadv}=0;

	$verbhash{total}=0;
	$verbhash{attempted}=0;
	$verbhash{correct}=0;
	$verbhash{wrong}=0;
	$verbhash{skipped}=0;
	$verbhash{asnoun}=0;
	$verbhash{asverb}=0;
	$verbhash{asadj}=0;
	$verbhash{asadv}=0;

	$adjhash{total}=0;
	$adjhash{attempted}=0;
	$adjhash{correct}=0;
	$adjhash{wrong}=0;
	$adjhash{skipped}=0;
	$adjhash{asnoun}=0;
	$adjhash{asverb}=0;
	$adjhash{asadj}=0;	
	$adjhash{asadv}=0;	

	$advhash{total}=0;
	$advhash{attempted}=0;
	$advhash{correct}=0;
	$advhash{wrong}=0;
	$advhash{skipped}=0;
	$advhash{asnoun}=0;
	$advhash{asverb}=0;
	$advhash{asadj}=0;	
	$advhash{asadv}=0;	
}

sub showUsage
{
    my $long = shift;
    print "Usage: allwords-scorer2.pl --ansfile FILE --keyfile FILE | {--help | --version}\n";

    if ($long) 
    {
	print "Options:\n";
       print "\t--ansfile            name of a file containing formatted answers\n";
	print "\t--keyfile            name of an answer-key file\n";
	print "\t--help               show this help message\n";
	print "\t--version            show version information\n";
    }
}

__END__

=head1 NAME

allwords-scorer2.pl - This perl script is used to score allwords 

=head1 SYNOPSIS

allwords-scorer2.pl --ansfile FILE --keyfile FILE

=head1 DESCRIPTION

=head1 scorer2

scorer2 is a C program used to score entries to Senseval.  The source
code is available for downloading:

L<http://www.senseval.org/senseval3/scoring>

=head1 AUTHORS

 Varada Kolhatkar, University of Minnesota, Duluth
 <kolha002 at d.umn.edu>

 Ted Pedersen, University of Minnesota, Duluth
 <tpederse at d.umn.edu>

This document last modified by : 
$Id: allwords-scorer2.pl,v 1.2 2009/02/11 02:50:33 kvarada Exp $

=head1 SEE ALSO

 L<scorer2-format.pl> L<semcor-reformat.pl> L<wsd-experiments.pl> L<scorer2-sort.pl>

=head1 COPYRIGHT 

Copyright (C) 2005-2008 by Jason Michelizzi and Ted Pedersen

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation; either version 2 of the License, or (at your
option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.
