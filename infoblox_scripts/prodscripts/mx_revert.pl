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
my ($api_hostname, $api_username, $api_password, $infoblox_view, $in_file, $skip_zone ) = ('', '', '', 'default','localhost','' ,''  );

#Declare globals here...
our ($hmmm) = ('hmmm');

GetOptions(
           "api_hostname=s" => \$api_hostname,
           "api_username=s" => \$api_username,
           "api_password=s" => \$api_password,
           "infoblox_view=s" => \$infoblox_view,
           "in_file=s" => \$in_file,
           "skip_zone=s" => \$skip_zone,
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
my $session = infoblox_connect($api_hostname, $api_username, $api_password);


#Open domain file
my @file_out = file_to_array($in_file);

print "Zone, Exchanger, New MX\n";

foreach my $line ( @file_out )
  {
 	my $zone = $line;	

	#You can use this array to track if the domain you are checking exists...
	my @validate_domain = infoblox_zone_search($session, $zone, $infoblox_view);

	if ( !@validate_domain || $zone eq $skip_zone )
	  {
		#If the domain does not exist...
		print "\n" . $zone . ", is not a zone hosted on " . $api_hostname . " or skipped.\n";
	  }
	else
	  {
              #If the domain exists do the following...
                my @mx_results = infoblox_mx_search($session, $zone, $infoblox_view);
                if ( @mx_results )
                  {
                        foreach my $results ( @mx_results )
                          {
                                my $change_mx = "No change required...";
                                my $change_priority = "";
                                print $results->zone() . ", ". $results->exchanger() . ", ";

                                #Start generating new MX records SON!
                                if ( $results->exchanger() =~ m/mx1.hargray.rcimx.net/ )
                                  {
                                        $change_mx = $results->zone() . ".s5a1.psmtp.com";
                                        $change_priority = "10";
                                  }
                                elsif ( $results->exchanger() =~ m/mx2.hargray.rcimx.net/ )
                                  {
                                        $change_mx = $results->zone() . ".s5a2.psmtp.com";
                                        $change_priority = "20";
                                  }
                                elsif ( $results->exchanger() =~ m/mx3.hargray.rcimx.net/ )
                                  {
                                        $change_mx = $results->zone() . ".s5b1.psmtp.com";
                                        $change_priority = "30";
                                  }
                                elsif ( $results->exchanger() =~ m/mx4.hargray.rcimx.net/ )
                                  {
                                        $change_mx = $results->zone() . ".s5b2.psmtp.com";
                                        $change_priority = "40";
                                  }
                                else
                                  {
                                        #EVERYTHING ELSE MAN
                                  }

                                #If their is a change_priority set then you need to delete the current MX
                                #and add a new one...
                                if ( $change_priority )
                                  {
                                        print "Attemping to add... ";
                                        my $bindmx = Infoblox::DNS::Record::MX->new(
                                        name      => $results->zone(),
                                        comment   => "modified for Edgewave rollout",
                                        pref      => $change_priority,
                                        exchanger => $change_mx,
                                        );
                                        # Submit for addition
                                        my $add_response = $session->add( $bindmx );

                                        #Remove the old MX record
                                        if ( $add_response )
                                          {
                                                print ", New Priority: " . $change_priority . " MX: " . $change_mx;
                                                my $desired_mx = $results;
                                                # Submit for removal
                                                my $delete_response = $session->remove( $desired_mx );
                                                if ( $delete_response )
                                                  {
                                                        print ",Old Mx: " . $results->exchanger() . " is deleted."
                                                  }
                                          }

                                  }

                                print $change_priority . " " .$change_mx . "\n";

                          }
                  }
                else
		  {
			print $zone . ", NO MX\n";
		  }
  	  }

  }
