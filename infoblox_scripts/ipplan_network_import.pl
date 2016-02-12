#!/usr/bin/perl

=pod

This script will provide you with a starting point for connecting to our InfoBlox Appliances
via the API.  

Created by: Robert Lupinek
Created on: 9/21/2012
Last Modified: 9/21/2012

=cut

use strict;
use warnings;
use Getopt::Long;
use Infoblox;


# Declare the options vars
my ($api_host, $api_user, $api_pass, $view, $in_file ) = ('', '', '', 'default', '');

#Declare globals here...
our ($hmmm) = ('hmmm');

GetOptions(
           "api_host=s" => \$api_host,
           "api_user=s" => \$api_user,
           "api_pass=s" => \$api_pass,
           "view=s" => \$view,
           "in_file=s" => \$in_file,
           );
           
#Validate all required options have been passed to the script
if ( !$api_host || !$api_user || !$api_pass || !$in_file )
{
        die "BLARGH!\nMissing options!\nRun script like below example:\n.\/ipplan_import.pl --api_host 172.19.253.50 --api_user api-ro --api_pass api-ro --in_file ./export.txt \n";
}

#Attempt to create a new session
my $session = infoblox_connect($api_host, $api_user, $api_pass);

#Open input file to convert to array
my @file_array = file_to_array($in_file);

my @split_line = ();

#Split and submit results for input to be added to Infoblox
foreach my $my_line ( @file_array )
{
	@split_line = split(/\t/, $my_line);	
	my $cidr = $split_line[0] . "\/" . dec_to_cidr($split_line[2] );
	my $comment = $split_line[1];
	
	print "Attempting to add "  . $cidr . " -- " . $comment . " -- " . "Netmask " . $split_line[2]  . "\n";
	
	if ( my $response = infoblox_add_network($session, $cidr, $comment) )
	{
		print "Success!\n";
	}
	else
	{
		print "Failed to add network.\n";
	};
	
	
}

#############################################################
#Subroutine that converts decimal netmask to cidr
sub dec_to_cidr
{
	my ( $dec_netmask ) = @_;
	(my $byte1, my $byte2, my $byte3, my $byte4) = split(/\./, $dec_netmask.".0.0.0.0");
	my $num = ($byte1 * 16777216) + ($byte2 * 65536) + ($byte3 * 256) + $byte4;
	#Binary representation of netmask
	my $bin = unpack("B*", pack("N", $num));
	#Bit count or CIDR notation
	my $count = ($bin =~ tr/1/1/);
	#print "$bin = $count bits\n";
	#As the name implies we return the CIDR :)
	return $count;
}

#############################################################
#Subroutine that opens a file and writes contents to an array
sub file_to_array
{
	my ( $file_name ) = @_;
	my @file_array = ();
	open (MYFILE, "<$file_name")
        or die "cannot open file: $file_name $!";
	foreach my $lines ( <MYFILE>)
	{
        push(@file_array, $lines);
	}
	close (MYFILE);
	return @file_array;
}

############################################################
#Subroutine to creates the network 
sub infoblox_add_network
{
	my ($session, $cidr, $comment) = @_;
	#Adding a network. Expects $cidr as 192.168.101.1/32
 	#Construct an object
 	my $network = Infoblox::DHCP::Network->new(
        network => $cidr,     
        comment => $comment,   
 	);
 	# Submit for adding a network
 	my $response = $session->add( $network );
 	
 	if ( !$response )
 	{
 		print Infoblox::status_code() . ":" . Infoblox::status_detail();
 	}
 	
 	return $response;
}
############################################################
#Subroutine to creates a session with the InfoBlox server 

sub infoblox_connect
{
  #Setup the initial connection to InfoBlox and pass back the session object...
  my ( $api_host, $api_user, $api_pass ) = @_;
  my $session = Infoblox::Session->new(
               "master" => $api_host,
               "username" => $api_user, 
               "password" => $api_pass 
             );

  die ("Constructor for session failed: ", Infoblox::status_code() . ":" . Infoblox::status_detail())
    unless $session && $session->{statuscode} == 0;
  return $session;
}  