#!/usr/local/bin/perl

use strict;
use warnings;

my $infile = shift;

unless (defined $infile) {
    print STDERR "No input file specified\n";
    showUsage();
    exit 1;
}
	
my $id = 0;

open FH, '<', $infile or die "Cannot open $infile: $!";
while (my $line = <FH>) {
    my @forms = split /\s+/, $line;
    foreach my $form (@forms) {
	my ($w, $p, $s) = split /\#/, $form;

	# inc the id number
	$id++;
	
	# check to see if there is a sense number assigned
	if ($s) {
	    print $w, '.', $p, ' ', $id, ' ', $s, "\n";
	}
	else {
	    # do nothing
	}
    }
}
close FH;

sub showUsage
{
    print "Usage: scorer2-format.pl INFILE1 [INFILE2 ...]\n";
}

__END__

=head1 NAME

scorer2-format.pl - Reformat wsd.pl output for use by the scorer2 evaluation program 

=head1 SYNOPSIS

 scorer2-format.pl INFILE1 [INFILE2 ...]

=head1 DESCRIPTION

This script reads one or more files from the command line and reformats
them so that they can be scored using the Senseval scorer2 program.  The
input format is that of the wsd.pl program that is distributed with
WordNet-SenseRelate.  The output is printed to the standard output.

Note: be sure to run wsd.pl with the '--silent' option.  If this is not
done, wsd.pl will print configuration information that will cause this
script to fail.

=head1 scorer2

scorer2 is a C program used to score entries to Senseval.  The source
code is available for downloading:

L<http://www.senseval.org/senseval3/scoring>

=head1 AUTHORS

 Jason Michelizzi

 Ted Pedersen, University of Minnesota, Duluth
 <tpederse at d.umn.edu>

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


