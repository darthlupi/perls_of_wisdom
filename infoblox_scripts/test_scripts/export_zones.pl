#!/usr/bin/perl	

########################################################
#Create an InfoBlox usable export of all zones in a Grid
#
#Creator: Robert Lupinek -- Created: 07/30/2012
#Modified by: Robert Lupinek -- Modified: 07/30/2012 
########################################################


use strict;
use warnings;
use Getopt::Long;
use Infoblox;

# Config params are global variables, go figure
our ($api_hostname, $api_username, $api_password, $infoblox_view, $zone ) = ('', '', '', 'default','localhost'  );
#Locals

GetOptions(
           "api_hostname=s" => \$api_hostname,
           "api_username=s" => \$api_username,
           "api_password=s" => \$api_password,
           "infoblox_view=s" => \$infoblox_view,
           );

if ( !$api_hostname || !$api_username || !$api_password || !$infoblox_view )
{
	die "BLARH!\n";
}

my $session = infoblox_connect();

my @result_array = $session->get(
        object => "Infoblox::DNS::Zone",
        name => $zone,
        view => $infoblox_view
);

#If the domain exists print all recodes for the zone...

if (!@result_array) 
{
	warn("DNS zone '$zone' does not exist\n");
           
}
else 
{
  	print "DNS zone '$zone' exists\n";
	
	print my @retrieved_objs = $session->get( 
     	object    => "Infoblox::DNS::Record::MX",
     	name      => $zone,
     	view      => $infoblox_view );	
	
	foreach my $results( @retrieved_objs )
	{
		print "cool";
	}

}

#################
#SUB ROUTINES
################# 
sub infoblox_connect {

  my $session = Infoblox::Session->new(
               "master" => $api_hostname,
               "username" => $api_username, 
               "password" => $api_password 
             );

  die ("Constructor for session failed: ", Infoblox::status_code() . ":" . Infoblox::status_detail())
    unless $session && $session->{statuscode} == 0;
  return $session;
} 


