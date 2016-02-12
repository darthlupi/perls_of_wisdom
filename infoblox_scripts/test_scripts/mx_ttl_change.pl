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

# Declare the options vars
my ($zone, $api_hostname, $api_username, $api_password, $infoblox_view, $in_file, $ttl ) = ('', '', '', '', 'default','localhost','' ,''  );

#Declare globals here...
our ($hmmm) = ('hmmm');

GetOptions(
           "api_hostname=s" => \$api_hostname,
           "api_username=s" => \$api_username,
           "api_password=s" => \$api_password,
           "infoblox_view=s" => \$infoblox_view,
           "in_file=s" => \$in_file,
           "ttl=s" => \$ttl,
	   "zone=s" => \$zone,
           );

sub file_to_array 
{
	my ($in_file) = @_;
	my @return_array;
 	open FILE, "<" , $in_file or die $!;

 	while (<FILE>) 
          {
 		chomp;
		push( @return_array, $_ );
 	  }
 	close (FILE);
	return @return_array;	
}


sub infoblox_connect
{
  #Setup the initial connection to InfoBlox and pass back the session object...
  my ( $api_hostname, $api_username, $api_password ) = @_;
  my $session = Infoblox::Session->new(
               "master" => $api_hostname,
               "username" => $api_username, 
               "password" => $api_password 
             );

  die ("Constructor for session failed: ", Infoblox::status_code() . ":" . Infoblox::status_detail())
    unless $session && $session->{statuscode} == 0;
  return $session;
}


sub infoblox_zone_search
{
	#Get basic zone info.  Useful for validation etc.
	my ( $session, $zone, $infoblox_view ) = @_;

	my @result_array = $session->search(
        	object => "Infoblox::DNS::Zone",
        	name => $zone,
        	view => $infoblox_view
	);

	return @result_array;

}

sub infoblox_mx_search
{
	#Get MX data for zone.
	my ( $session, $zone, $infoblox_view ) = @_;

       	#Grab MX records for validation...
       	my @results_array = $session->search(
               	object    => "Infoblox::DNS::Record::MX",
               	name      => $zone,
               	view      => $infoblox_view );

	return @results_array;

}


#Initial connection
print "Connecting...\n";
my $session = infoblox_connect($api_hostname, $api_username, $api_password);



if ( $zone )
  {
	print "CONNECTED...\n";
	#Initial connection
	#You can use this array to track if the domain you are checking exists...
	my @validate_domain = infoblox_zone_search($session, $zone, $infoblox_view);
	
	print "\nChecking the zone: " . $zone . ".\n";
	
	if ( !@validate_domain )
	  {
		#If the domain does not exist...
		print "\n" . $zone . ", is not a zone hosted on " . $api_hostname . ".\n";
	  }
	else
	  {
  		#If the domain exists do the following...
		my @mx_results = infoblox_mx_search($session, $zone, $infoblox_view);
		if ( @mx_results )
		  {
			print "Modifing TTL's for zone " . $zone . "\n";
        		foreach my $result_mx ( @mx_results )
        	  	  { 

				print "MODIFY TTL FOR MX " . $result_mx->exchanger() . " equal to: " . $ttl . " seconds.\n";
				$result_mx->ttl($ttl);
 				# Submit for addition
				
 				#my $modify_response = $session->modify( $result_mx );
				sleep(1);

        	  	  }
		  }
		else
		  {
			print $zone . ", NO MX\n";
		  }
  	  }

  }
