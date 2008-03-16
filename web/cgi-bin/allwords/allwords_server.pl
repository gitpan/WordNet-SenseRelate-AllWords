#!/usr/local/bin/perl

use IO::Socket;
use WordNet::QueryData;
use WordNet::Tools;
use WordNet::SenseRelate::Tools;
use WordNet::SenseRelate::AllWords;
use WordNet::Similarity;

my $wnlocation = '/usr/local/WordNet-3.0/dict';
my $text;
my $windowSize;
my $format;
my $scheme;
my $logfile="./log.txt";

my $localhost = '127.0.0.1';
my $localport = 7070;
my $proto = "tcp";
my $argument=shift;
if( $argument eq 'stop' )
{
	die "Server Stopped sucessfully";
}

my $success = open LFH, ">>$logfile";
if(!$success)
{
	print "\nCannot open $logfile for writing: $!";
}
else
{
	print "\nWriting log in $logfile";
}
	print LFH "WordNet Location => $wnlocation\n";

#. ....................................
#
# Creating WordNet::QueryData object.
#
#......................................

my $qd = WordNet::QueryData->new($wnlocation);
$qd ? print LFH "\nWordNet::QueryData object sucessfully created" :print LFH "\nCouldn't construct WordNet::QueryData object"; 

my %options;
my $stoplistfile;
my $stopword;
my $stopwordflag=0;
my $istagged=0;
my $showversion=0;
my $usr_dir;
my $tracefilename;
my $resultfilename;
my $doc_base = "../../htdocs/allwords/user_data";

#...........................................................................
#
# Currently, the compounding is done using WordNet::SenseRelate::Tools. 
# This is another way to compoundify. 
# my $preprocess = WordNet::SenseRelate::Preprocess::Compounds->new($wntools);
# $preprocess or print "Couldn't construct WordNet::SenseRelate::Preprocess::Compounds object";
#
#...........................................................................

my $wn = WordNet::SenseRelate::Tools->new("/usr/local/WordNet-3.0/dict");
$wn ? print LFH "\nWordNet::SenseRelate::Tools object sucessfully created" :print LFH "\nCouldn't construct WordNet::SenseRelate::Tools object"; 

my $sock = new IO::Socket::INET (
                LocalHost => $localhost,
                LocalPort => $localport,
                Proto => $proto,
                Listen => SOMAXCONN,
                Reuse => 1,
                timeout => 5,
                );
$sock ? print LFH "\nSocket created with following details \nLocalHost => $localhost\nLocalPort => $localport\nProto => $proto" : print LFH "\nCould not create socket: $!\n";
print LFH "\n[Server $0 accepting clients]\n";
while ($client = $sock->accept()){	
   $client->autoflush(1);	
   print LFH "\nClient $client is accepted\n";	
   %options= (wordnet => $qd);
   while(defined ($line = <$client>))
   {	
	chomp($line);
	@tokens=split(/:/,$line);
		if ($line =~ /version information/) 
		{
		    # get version information
			my $wntools = WordNet::Tools->new($qd);
			$wntools ? print LFH "\n WordNet::Tools object Sucessfully created" :print LFH "\nUnable to create WordNet::Tools object"; 

		    my $qdver = $qd->VERSION ();
			my $wnver = $wntools->hashCode ();
		    my $simver = $WordNet::Similarity::VERSION;
			my $allwordsver = $WordNet::SenseRelate::AllWords::VERSION;
			print LFH "\nv WordNet $wnver";
			print LFH "\nv WordNet::QueryData $qdver";
		    print LFH "\nv WordNet::Similarity $simver";
			print LFH "\nv WordNet::SenseRelate::AllWords $allwordsver";

			print $client "v WordNet $wnver\n";
			print $client "v WordNet::QueryData $qdver\n";
			print $client "v WordNet::Similarity $simver\n";
			print $client "v WordNet::SenseRelate::AllWords $allwordsver\n";
			$showversion=1;
			print LFH "\nShow verrion flag => $showversion";
			close($client);	
		}
		elsif ($line =~  /Document Base:/)
	    {
			$doc_base=$tokens[1];
			print LFH "\nDocument Base => $doc_base";
	    }
		elsif ($line =~  /User Directory:/)
	    {
			$usr_dir="$tokens[1]";
			print LFH "\nUser Directory => $usr_dir";
			$tracefilename="$usr_dir"."/trace.txt";
			$resultfilename="$usr_dir"."/results.txt";
			print LFH "\nTrace file name => $tracefilename";
	    }
		elsif ($line =~ /Text to Disambiguate:/)
		{
			$showversion=0;
			$text=$tokens[1];
			print LFH "\nText => $text";
	    }
		elsif ($line =~ /Window size:/)
		{
			$windowSize=$tokens[1];
			print LFH "\nWindow Size => $windowSize";
	    }elsif ($line =~ /Format:/)
	    {
			$format=$tokens[1];
			$istagged = $format eq 'tagged' ? 1 : 0;
			print LFH "\nformat => $format";
			$istagged eq 1 ? print LFH "\ntagged text => YES": print LFH "\ntagged text => NO" ;
	    }elsif ($line =~ /Scheme:/)
	    {
			$scheme=$tokens[1];
			print LFH "\nscheme => $scheme";
	    }elsif ($line =~ /trace:/)
	    {
			$options{trace} = $tokens[1];
	    }elsif ($line =~ /pairScore:/)
	    {	
			$options{pairScore} = $tokens[1];
	    }elsif ($line =~ /measure:/)
	    {	
			$options{measure} = "WordNet::Similarity::"."$tokens[1]";

		}elsif ($line =~ /contextScore:/)
	    {	
			$options{contextScore} = $tokens[1];
	    }elsif ($line =~ /stoplist:/)
	    {	
			$options{stoplist} = $tokens[1];
	    }elsif($line eq "End\0012")
		{
			last;
		}
   }
if (!$showversion) {
print LFH "\nThe options are: \n";
foreach $temp (keys(%options)) 
{ 
	print LFH "$temp=>".$options{$temp} . "\n";
} 	

   my $obj = WordNet::SenseRelate::AllWords->new(%options);
   $obj ? print LFH "\nWordNet::SenseRelate::AllWords object successfully created":print LFH "\nCouldn't construct WordNet::SenseRelate::AllWords object";
   chomp($text);
   if ($format ne "tagged" && $format ne "wntagged") {
	   my $newtext = $wn->compoundify($text);
	   $text = $newtext;
  	   print LFH "\nText after compoundifying is => $text";
   }

   @context=split(/ +/,$text);

#.....................................................................
#
# This is the call to disambigute the sentence which client has sent
#
#.....................................................................

 	my @res = $obj->disambiguate (window => $windowSize,
				  scheme => $scheme,
			      tagged => $istagged,
			      context => [@context]);

#..................................................................................
#
# This will change in the next version. Currently this is the code to 
# identify if the word returned by disambiguate actually has a valid sense 
# in the surrounding context, or if it is a stopword, or not defined by WordNet
# or is not related to the surrounding words. This identification will eventually 
# go in allwords.pm and any client of allwords.pm would be able to make this 
# distinction.
#
#.................................................................................
open RFH, '>', $resultfilename or print "Cannot open $resultfilename for writing: $!";
print RFH join (' ', @res), "\n";
print LFH join (' ', @res), "\n";
print $client join (' ', @res), "\n";
    foreach $val (@res)
  	{
		chomp($val);
		print LFH "\nWord after disambiguation => $val";
		if(($obj->isStop($val)) && ($val !~ /#/))
		{
			print LFH "\n$val : stopword\n";
			print RFH "\n$val : stopword\n";
			print $client "\n$val : stopword\n";
		}
		else
		{
			if ($val =~ /#/) 
			{
				my ($gloss) = $qd->querySense ($val, "glos");
				print LFH "\n$val : $gloss\n";
				print RFH "\n$val : $gloss\n";
				print $client "\n$val : $gloss\n";
			}
			else
			{
				my ($gloss) = $qd->querySense ($val, "glos");
				if ($gloss) 
				{
					print LFH "\n$val: No relatedness found with the surrounding words\n";
					print RFH "\n$val: No relatedness found with the surrounding words\n";
					print $client "\n$val: No relatedness found with the surrounding words\n";

				}
				else 
				{
					print LFH "\n$val : not in WordNet\n";
					print RFH "\n$val : not in WordNet\n";
					print $client "\n$val : not in WordNet\n";
				}
			}
		}
  	}
	close RFH;

	if ($options{trace}) {
			open TFH, '>', $tracefilename or print "Cannot open $tracefilename for writing: $!";
			print TFH join (' ', @res), "\n";
			my $tstr = $obj->getTrace();
			print TFH "$tstr \n";
			print LFH "$tstr \n";
			close TFH;
	}

	
	$status=system("tar -cvf $usr_dir.tar $usr_dir >& tar_log");
	$status == 0 ? print LFH "\nThe tar file of results successfully created.":print LFH "\nError while creating the tar file of results."; 

	$status=system("gzip $usr_dir.tar");
	$status==0 ? print LFH "\nThe zip tar file of results successfully created.":print LFH "Error while zipping the tar file of results.";


	$status=system("mv $usr_dir.tar.gz $doc_base/allwords/user_data/");
	$status == 0 ? print LFH "The tar file successfully copied to $doc_base" :print LFH "Error while copying the tar file.";

	$status=system("mv $usr_dir $doc_base/allwords/user_data/");
	if($status != 0)
	{
		print LFH "Can not create user directory in /htdocs.";
	}
}
	close($client);	
}

=head1 NAME

allwords_server.pl - the server for allwords.cgi and version.cgi

=head1 SYNOPSIS

$client = $sock->accept();

my $obj = WordNet::SenseRelate::AllWords->new(%options);

my @res = $obj->disambiguate (window => $windowSize, scheme => $scheme, tagged => $istagged, context => [@context]);

foreach $val (@res)
	print $client "\n$val : $gloss\n";
	
=head1 DESCRIPTION

This script implements the backend of the web interface for
WordNet::SenseRelate::AllWords

This script listens to a port waiting for a request form allwords.cgi or
version.cgi. 
If disambiguation request is made by allwords.cgi, the server first gets input options from allwords.cgi. Then it creates AllWords object. Using AllWords object and input options 
disambiguate method is called. The result returned by disambiguate is checked and appropriate message is sent back to allwords.cgi client. 

If the version information is requested, appropriate version information of the respective components is fetched and is passed to version.cgi client.

If the client requests for trace level, then trace output is fetched calling getTrace() method of AllWords.pm.

After all processing is done, it moves the user_data along with the tarball of result files 
to htdocs/allwords/user_data directory.


=head1 AUTHORS

 Varada Kolhatkar, University of Minnesota, Duluth
 kolha002 at d.umn.edu

 Ted Pedersen, University of Minnesota, Duluth
 tpederse at d.umn.edu

This document last modified by : 
$Id: allwords_server.pl,v 1.6 2008/03/15 22:22:20 kvarada Exp $ 

=head1 SEE ALSO

allwords.cgi, version.cgi, README.web.pod

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2008, Varada Kolhatkar, Ted Pedersen, Jason Michelizzi

Permission is granted to copy, distribute and/or modify this document
under the terms of the GNU Free Documentation License, Version 1.2
or any later version published by the Free Software Foundation;
with no Invariant Sections, no Front-Cover Texts, and no Back-Cover
Texts.

Note: a copy of the GNU Free Documentation License is available on
the web at L<http://www.gnu.org/copyleft/fdl.html> and is included in
this distribution as FDL.txt.

=cut
