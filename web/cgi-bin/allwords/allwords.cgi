#!/usr/local/bin/perl -w
use IO::Socket;
use CGI;
$CGI::DISABLE_UPLOADS = 0;

# Here we connect to the AllWords server
my $host='127.0.0.1';
my $port=7070;

my $OK_CHARS='-a-zA-Z0-9_\' ';
my ($kidpid, $handle, $line);
my %options;
my $status;
my $filename="clientinput.txt"; 
my $inputfile;
my $stoplistfile;
my $defstoplistfile="./default-stoplist-raw.txt";
my $defstop="off";
my $contextfile;
my $contextfilename;
my $stoplistfilename;
my $stoplist;
my $configfilename;
my $configfile;
my $config;
my $hostname;
my @tracelevel=();

BEGIN {
    # The carpout() function lets us modify the format of messages sent to
    # a filehandle (in this case STDERR) to include timestamps
    use CGI::Carp 'carpout';
    carpout(*STDOUT);
}

my $cgi = CGI->new;

# print the HTTP header
print $cgi->header;
$hostname=$ENV{'SERVER_NAME'};

my $usr_dir="user_data/". "user".time();
$inputfile="$usr_dir/"."input.txt";
$status=system("mkdir $usr_dir");
if($status!=0)
{
	writetoCGI("Can not create the user directory $usr_dir");
}


my $text = $cgi->param('text1') if defined $cgi->param('text1');
$contextfile=$cgi->param('contextfile') if defined $cgi->param('contextfile');

#if ($cgi->param('text1') eq "" && $cgi->param('contextfile') eq "") {

if ( (!$text)  && (!$contextfile) ) {
	    writetoCGI("\nPlease use back link to return to original page to enter your text\n");
		print "<p><a href=\"http://$hostname/allwords/allwords.html\">Back</a></p>";
		die "Could not complete the request as no text was entered. \n";
}

if($contextfile){
	$contextfilename = getFileName($contextfile);
	$context="$usr_dir/"."$contextfilename";
	open CONTEXT,">","$context" or writetoCGI("Error in uploading contextfile.");
	while(read($contextfile,$buffer,1024))
	{
		print CONTEXT $buffer;
	}
	close CONTEXT;	
}

my $windowSize = $cgi->param('winsize') if defined $cgi->param('winsize');
my $format = $cgi->param('format') if defined $cgi->param('format');
$options{wnformat} = 1 if $format eq 'wntagged';
my $scheme = $cgi->param('scheme') if defined $cgi->param('scheme');

if ($cgi->param('measure') =~ /lesk/) {
	$options{measure}= "lesk";
}elsif($cgi->param('measure') =~ /path/) {
	$options{measure}= "path";
}elsif($cgi->param('measure') =~ /wup/) {
	$options{measure}= "wup";
}elsif($cgi->param('measure') =~ /lch/) {
	$options{measure}= "lch";
}elsif($cgi->param('measure') =~ /hso/) {
	$options{measure}= "hso";
}elsif($cgi->param('measure') =~ /res/) {
	$options{measure}= "res";
}elsif($cgi->param('measure') =~ /lin/) {
	$options{measure}= "lin";
}elsif($cgi->param('measure') =~ /jcn/) {
	$options{measure}= "jcn";
}elsif($cgi->param('measure') =~ /vector/) {
	$options{measure}= "vector";
}elsif($cgi->param('measure') =~ /vector-pairs/) {
	$options{measure}= "vector-pairs";
}

$configfile=$cgi->param('configfile') if defined $cgi->param('configfile');
if($configfile){

	$configfilename = getFileName($configfile);
	$config="$usr_dir/"."$configfilename";
	$options{config} = "$usr_dir/"."$configfilename";
	open CONFIG ,">","$config" or writetoCGI("Error in uploading Config file.");
	while(read($configfile,$buffer,1024))
	{
		print CONFIG $buffer;
	}
	close CONFIG;
}

# If the user uploads his own stoplist as well as keep the default stoplist option checked, 
# the stoplist included by the user will always override the default

$stoplistfile=$cgi->param('stoplist');

if(!$stoplistfile)
{
	$defstop=$cgi->param('defstoplist') if defined $cgi->param('defstoplist');
	if ($defstop eq "on") {
		$options{stoplist} = "$defstoplistfile";
		$status=system("cp $defstoplistfile $usr_dir/$defstoplistfile");
		print "Error while copying the stoplist file." unless $status==0;
	}
}
else{
	$stoplistfilename = getFileName($stoplistfile);
	$stoplist="$usr_dir/"."$stoplistfilename";
	$options{stoplist} = "$usr_dir/"."$stoplistfilename";
	open STOPLIST,">","$stoplist" or writetoCGI("Error in uploading Testfile.");
	while(read($stoplistfile,$buffer,1024))
	{
		print STOPLIST $buffer;
	}
	close STOPLIST;
}

$options{pairScore} = $cgi->param('pairscore') if defined $cgi->param('pairscore');
$options{contextScore} = $cgi->param('contextscore') if defined $cgi->param('contextscore');
#.............................................................................
#
# storing different tracelevels in an array so that it would be useful to show
# traces of different levels.
#
#..................................................................................
$tracelevel[0] = defined $cgi->param('level1') ? $cgi->param('level1') : 0;
$tracelevel[1] = defined $cgi->param('level2') ? $cgi->param('level2') : 0; 
$tracelevel[2] = defined $cgi->param('level4') ? $cgi->param('level4') : 0; 
$tracelevel[3] = defined $cgi->param('level8') ? $cgi->param('level8') : 0; 
$tracelevel[4] = defined $cgi->param('level16') ? $cgi->param('level16') : 0; 
$tracelevel[5] = defined $cgi->param('level32') ? $cgi->param('level32') : 0; 

foreach $trace (@tracelevel) {
	if( $trace > 0){
			$options{trace}= defined $options{trace} ? ($options{trace} + $trace) : $trace;
	}
}

$options{forcepos} = $cgi->param('forcepos') if defined $cgi->param('forcepos');



# Removing unwanted characters from the raw text. If the text is tagged or wntagged, 
# 
#
if ($format ne 'tagged' && $format ne 'wntagged') {
	$text =~ s/[^$OK_CHARS]/ /g;
	#$text =~ s/[^-a-zA-Z0-9_' ]/ /g;
	$text =~ s/([A-Z])/\L$1/g;
}

open FH, '>', $filename or die "Cannot open $filename for writing: $!";
open IFH, '>', $inputfile or die "Cannot open $inputfile for writing: $!";

print FH "Document Base:$ENV{'DOCUMENT_ROOT'}\n";
print FH "User Directory:$usr_dir\n";
print IFH "User Directory:$usr_dir\n";

if ($text ne "") {
	print FH "Text to Disambiguate:$text\n";
	print IFH "Text to Disambiguate:$text\n";
}
else
{
	print FH "Contextfile:$contextfilename\n";
	print IFH "Contextfile:$contextfilename\n";
}


print FH "Window size:$windowSize\n";
print IFH "Window size:$windowSize\n";

print FH "Format:$format\n";
print IFH "Format:$format\n";

print FH "Scheme:$scheme\n";
print IFH "Scheme:$scheme\n";

while (($key, $value) = each %options) {
	print FH "$key:$value\n";
	print IFH "$key:$value\n";
}
print FH "End\0012\n";
close IFH;
close FH;


my $sock=new IO::Socket::INET(
                        PeerAddr => $host,
                        PeerPort => $port,
                        Proto => 'tcp',
                        );
if( !defined $sock)
{
 	writetoCGI("Sorry WordNet::SenseRelate::AllWords is down. Please try later");
	die "Could not create socket: $!\n";
}
$sock->autoflush(1);
die "can't fork: $!" unless defined($kidpid = fork());
# the if{} block runs only in the parent process
    if ($kidpid)
    {
        # copy the socket to CGI output
        while (defined ($line = <$sock>))
        {
			$line =~ s/</< /g;
			$line =~ s/>/ >/g;
			$line =~ s/\#o|\#NR|\#ND|\#IT|\#NT|\#CL|\#MW//g;
			writetoCGI($line);
        }
        kill("TERM", $kidpid);                  # send SIGTERM to child
	print "<br><br>";
	if (defined $options{trace}) 
	{
			print $cgi->a({-href=>"/allwords/$usr_dir/trace.txt"},"See Trace output");
			print "<br><br>";
	}
	print $cgi->a({-href=>"/allwords/$usr_dir.tar.gz"},"Download");
	print " the complete tar ball of the result files.", $cgi->p;
	print $cgi->a({-href=>"/allwords/$usr_dir"},"Browse");
	print " your directory.", $cgi->p;
    }
    # the else{} block runs only in the child process
    else
    {
	open FH, '<', $filename or die "Cannot open $filename for reading: $!";
        #copy CGI input to the socket
	while (defined ($line = <FH>))
	{
	     print $sock $line;
	}
	close FH;
	print "<p><a href=\"http://$hostname/allwords/allwords.html\">Start Over</a></p>";
    }


sub writetoCGI
{
my $output=shift;
print <<EndHTML;
<html><head><title>Results</title></head>
<body>
$output<br>
EndHTML
}

sub getFileName
{
	my $path=shift;
	my $filename;
	my $result = rindex($path, "\/");
	if ($result eq -1) {
		$result = rindex($path, "\\");
	}
	$filename= substr $path, $result+1;
	return $filename;
}
=head1 NAME

allwords.cgi - [Web] CGI script implementing a portion of a web interface for WordNet::SenseRelate::AllWords

=head1 SYNOPSIS

	read input data 
	connect to allwords_server.pl
	send input data to the server
	Get results from the server
	Display results

=head1 DESCRIPTION

This script works in conjunction with allwords_server.pl to
provide a web interface for L<WordNet::SenseRelate::AllWords>. The html 
file, htdocs/allwords/allwords.html posts the data entered by the user 
to this script. The data is written in a file and sent to the server line by line.
Then it waits for the server to send results. After receiving results, 
they are displayed to the user.

=head1 AUTHORS

 Varada Kolhatkar, University of Minnesota, Duluth
 kolha002 at d.umn.edu

 Ted Pedersen, University of Minnesota, Duluth
 tpederse at d.umn.edu

This document last modified by : 
$Id: allwords.cgi,v 1.14 2008/05/21 20:44:53 kvarada Exp $

=head1 SEE ALSO

allwords_server.pl, README.web.pod

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
