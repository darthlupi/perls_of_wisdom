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
my ($api_host, $api_user, $api_pass, $view ) = ('', '', '', 'default', );

#Declare globals here...
our ($hmmm) = ('hmmm');

GetOptions(
           "api_host=s" => \$api_host,
           "api_user=s" => \$api_user,
           "api_pass=s" => \$api_pass,
           "view=s" => \$view,
           );
           
#Validate all required options have been passed to the script
if ( !$api_host || !$api_user || !$api_pass )
{
        die "BLARGH!\nMissing options!\nRun script like below example:\n.\/connect_template.pl --api_host 172.19.253.50 --api_user api-ro --api_pass api-ro";
}

#Attempt to create a new session
my $session = infoblox_connect($api_host, $api_user, $api_pass);


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