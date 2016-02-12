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
        die "BLARGH!\nMissing options!\nRun script like below example:\n.\/ipplan_ip_details_import.pl --api_host 172.19.253.50 --api_user api-ro --api_pass api-ro --in_file ./export.txt \n";
}

#Attempt to create a new session
my $session = infoblox_connect($api_host, $api_user, $api_pass);

#Open input file to convert to array
my @file_array = file_to_array($in_file);

my @split_line = ();

#Split and submit results for input to be added to Infoblox
#This is for loading IP Details
foreach my $my_line ( @file_array )
{
	@split_line = split(/\t/, $my_line);	
	
	#Description
	if (!$split_line[1] )
	{
		$split_line[1] = "";
	}
	
	#Location
	if (!$split_line[2] )
	{
		$split_line[2] = "";
	}
	
	if (!$split_line[3] )
	{
		$split_line[3] = "";
	}		
	
	my $ip_address = $split_line[0];
	my $comment = $split_line[1];
	
	print "Attempting to add "  . $split_line[0] . " -- Description: " . $split_line[1] . " -- Location: " . $split_line[2]  .  " -- " . $split_line[3] . "\n";
	
	if ( validate_ip( $ip_address )  )
	{
		my $response = infoblox_add_ip_reservation($session, $ip_address, $comment);
		if ( $response )
		{
			print "Success!\n";
		}
		else
		{
			print "Failed to add IP Details.\n" . $session->status_detail() . " " . $session->status_code()  . "\n";
		}
	}
	else
	{
		print "$ip_address is not a valid IP Address!\n";
	}
	
	
}



#############################################################
#Checks to make sure we are working with a valid IP address
sub validate_ip
{
	my ( $ipaddr ) = @_;
 
	if( $ipaddr =~ m/^(\d\d?\d?)\.(\d\d?\d?)\.(\d\d?\d?)\.(\d\d?\d?)$/ )
	{
    	print("IP Address $ipaddr  -->  VALID FORMAT! \n");
    	if($1 <= 255 && $2 <= 255 && $3 <= 255 && $4 <= 255)
    	{
        	print("IP address:  $1.$2.$3.$4  -->  All octets within range\n");
        	return 1;
    	}
    	else
    	{
        	print("One of the octets is out of range.  All octets must contain a number between 0 and 255 \n");
        	return 0;
    	}
	}
	else
	{
    	print("IP Address $ipaddr  -->  NOT IN VALID FORMAT! \n");
    	return 0;
	}

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
#Subroutine to add reservation
sub infoblox_add_ip_reservation
{
	#Add IP Details as a fixed address RESERVED.
	
	my ($session, $ip_address, $comment) = @_;
	
	my $fixed_addr = Infoblox::DHCP::FixedAddr -> new(
       ipv4addr                        => $ip_address,                   #Required
       comment                         => $comment,                     #Optional / Default is empty
       match_client                    => "RESERVED",                     #Optional / Default is "MAC"
       #name                            => $name,                       #Optional
 );
 	
 	# Submit for adding a network
 	my $response = $session->add( $fixed_addr );
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