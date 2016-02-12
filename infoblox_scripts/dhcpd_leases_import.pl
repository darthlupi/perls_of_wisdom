

#!/usr/bin/perl 
#
# $Id: dhcpd_leases_import.pl,v 1.1 2006/10/26 22:55:54 horne Exp $
#
# Copyright (C) 2005 Infoblox, Inc.
# All Rights Reserved
#

package Infoblox::DHCP::Import::ISCleases;

use strict;
# use warnings;
use FindBin ();
use Getopt::Long;
use Carp;
use Data::Dumper;
$Data::Dumper::Indent = 1;
$Data::Dumper::Pad = ">>   ";

# Look for Infoblox.pm in a few more places
#
BEGIN { push @INC, "./lib"; push @INC, "$FindBin::Bin"; push @INC, "$FindBin::Bin/lib"; }

use Infoblox;

my $basename = $FindBin::Script;

my ($username, $password, $appliance, $verbose, $terse, $debug, $overwrite, $dryrun, $help, $session, $file, $complete, $linenum);

END { unless ($complete) { printf "Failed at line %d of file '%s'\n", $linenum, $file; } }

sub usage {
     Getopt::Long::HelpMessage( { "-exitval" => 1, "-msg" => shift } );
}

GetOptions (
	"s|server=s"	=> \$appliance,
	"u|username=s"	=> \$username,
	"p|password:s"	=> \$password,
	"v|verbose+"	=> \$verbose,
	"t|terse"	=> \$terse,
	"d|debug:s"	=> \$debug,
	"overwrite"	=> \$overwrite,
	"n|dry-run"	=> \$dryrun,
	"h|help"	=> sub { Getopt::Long::HelpMessage( { "-exitval" => 1, "-msg" => "Try 'perldoc qip-dhcp-to-3x.pl' for option usage" } ) } );

unless ($appliance && $username) {  usage("\nMissing required options... try 'perldoc $basename' for detailed usage\n"); }
unless ($#ARGV >= 0) { usage("\nAt least one leases file is required\n"); }

=head1 NAME

 dhcpd_leases_import.pl - Script to import ISC DHCP leases into an Infoblox 3.x Cluster

=head1 SYNOPSIS

 dhcpd_leases_import.pl -s <DNS One> -u <username> [ -p <password> ]
	            [ --overwrite ] [ -n | --dry-run ]
		    <file> .. <file>

 OPTIONS

   -s <ipaddr>       IP address of DNS One appliance (Cluster Master)
   -u <username>     Username of account with access rights
   -p <password>     Password, instead of prompting

   --overwrite       Overwrite existing leases
   --dry-run         Don't actually perform any actions
   -h                Um, this text

   <file> .. <file>  Address Lease file(s) from ISC DHCP server (dhcpd.leases)

=cut

unless ($dryrun || $password) {
  my $count = 3;
  while ( ! $password && $count-- ) {
    system "stty -echo";
    print "Password: ";
    chomp($password = <STDIN>);
    print "\n";
  }
  system "stty echo";
  exit unless $password;
}

unless ($dryrun) {
  $session = Infoblox::Session->new(
       "master" => $appliance,
       "username" => $username,
       "password" => $password);
}

$| = 1;

while ($file = shift) {
    
  if ($dryrun) {
    print "File '$file'... [ dryrun ].\n";
  } else {
    print "File '$file', uploading... ";
    if ( $session->import_data( "type" => "leases", "path" => "$file", "format" => "ISC" ) ) {
#				"overwrite" => ($overwrite ? "true" : "false") )   #  Not there yet, FIX ME
      printf "Done.\n";
    } else {
      printf "FAILED.\n  --> %s\n", $session->status_detail();
    }
  }
  $complete++;
}

#
# $Log: dhcpd_leases_import.pl,v $
# Revision 1.1  2006/10/26 22:55:54  horne
#
# BugId: 8205
# Reviewer(s): geoff
# Description: archive removal
#
# Revision 1.2  2005/05/24 21:48:49  milli
# BugId: 8205
# Reviewer(s): none
# Description: Fixed up filename in docs, added -d option (though -v and -d don't do anything)
#
# Revision 1.1  2005/05/18 20:40:01  milli
# BugId: 8205
# Reviewer(s): none
# Description: Renamed
#
# Revision 1.1  2005/05/18 17:24:32  milli
# BugId: 8205
# Reviewer(s): none
# Description: New script to import ISC DHCP leases
#
