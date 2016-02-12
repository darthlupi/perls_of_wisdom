#!/usr/bin/perl	

########################################################
#Change MX Records for the zone specified
#
#Creator: Robert Lupinek -- Created: 01/30/2012
#Modified by: Robert Lupinek -- Modified: 01/30/2012 
########################################################


use strict;
use warnings;
use Getopt::Long;
use Infoblox;

# Config params are global variables
our ($api_hostname, $api_username, $api_password, $infoblox_view, $zone, $new_mx, $old_mx ) = ('', '', '', 'default','localhost','','' );
#Locals

GetOptions(
           "api_hostname=s" => \$api_hostname,
           "api_username=s" => \$api_username,
           "api_password=s" => \$api_password,
           "infoblox_view=s" => \$infoblox_view,
	   "zone=s" => \$zone
           );


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
	
	for each my $results ( @retrieved_objs )
	{
		echo
	}

} 


