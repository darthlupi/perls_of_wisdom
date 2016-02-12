#!/usr/bin/perl -w
use strict;
use XML::Parser;
#use XML::Simple; #We are using the standard parser
use LWP::Simple;  # used to fetch the RedCondor XML data via it's API
use LWP::UserAgent; #used to post the final xml
use Getopt::Long;
use List::Compare;

########################################################
#Pull mailbox name and status by domain from XML docs
#downloaded via the RedCondor API.
#
#
#Creator: Robert Lupinek -- Created: 03/09/2012
#Modified by: Robert Lupinek -- Modified: 03/09/2012 
########################################################

# Declare the options vars
my ($domain, $email, $password, $xml_file, $dashboard, $delete_file ,$xml_out_file,$in_token ) = ( '', '', '', '',  '', '', '' , '');

GetOptions(
           "domain=s" => \$domain,          #Domain to pull accounts for REQUIRED
           "email=s" => \$email,            #Username for API login      REQUIRED
           "password=s" => \$password,      #Password for API login      REQUIRED
           "xml_file=s" => \$xml_file,      #Optional XML file           OPTIONAL
           "dashboard=s" => \$dashboard,    #Dashboard URL               REQUIRED
           "delete_file=s" => \$delete_file,  #Dashboard URL             REQUIRED
           "xml_out_file=s" => \$xml_out_file,		#Predelete accounts settings REQUIRED
           "in_token=s" => \$in_token,		#Predelete accounts settings REQUIRED
           );
           
if ( ( !$domain  || !$email || !$password || !$dashboard || !$delete_file || !$xml_out_file ) )
{
	die "This script needs to be run like so:\n delete_mailboxes.pl --domain hargray.com --email email\@hargray.com --password password --dashboard http://hargray.redcondor.net --xml_out_file path_to_outfile --delete_file cg_rad_delete_users.txt\nOptionally use --xml_file path_to_xml for alternate input...\nYou can also specify a token externally by using the --in_token the_token option\n";
}


############################################################################   
#Setup variables for connecting to the RedCondor API host
my $token_get_url= $dashboard . '/api/login?email=' . $email . '&password=' . $password;
my $token = ''; #Token variable that will store authentication token ( Valid for 24 hours )
my $xml_out = ''; #This is the variable that will hold the XML out via the 

############################################################################       
#Set up the variables for parsing the RedCondor XML doc
my $parser = new XML::Parser(ErrorContext => 2 );
my $count = 0;
my $tag = "";   
my $mailbox = "";
my $mailbox_status = "";
my @redcondor_mailboxes = (); #Array to store all of our lovely RedCondor address

#Set up the variables for collecting communigate data
my @delete_mailboxes = ();

#Set up the variables for deleting accounts from RedCondor
my @delete_list = ();
#Variable to store the contents of our XML document
my @xml_out_file_contents = ();


###################################
#SETUP XML EVENT DRIVEN FUNCTIONS
###################################

#The subroutine for the event Start :)
sub startElement 
{
       my( $parseinst, $element, %attrs ) = @_;
       SWITCH: {
              if ($element eq "mailbox") {
                     $count++;
                     $tag = "mailbox";
                     $mailbox = $attrs{'name'} . '@' . $domain;
                     $mailbox_status = $attrs{'status'};  #Example of how to retrieve and elements attributes
                     push(@redcondor_mailboxes, $mailbox );
                     #print "Mailbox:$mailbox\@$domain Status:$mailbox_status Current Mailbox:$count\n";
                     last SWITCH;
              }
              if ($element eq "domain") {
              	     $domain = $attrs{'name'};
                     print "Domain: ";
                     $tag = "domain";
                     last SWITCH;
              }
       }
}

sub endElement 
{
       my( $parseinst, $element ) = @_;
       #No need to play with the end element in this script...
       #SWITCH: {
       #       if ($element eq "mailbox") {
       #              print "Closing mailbox...\n";
       #              last SWITCH;
       #       }
       #       if ($element eq "domain") {
       #       	     print "Closing domain...\n";
       #              last SWITCH;
       #       }
       #}
}

#Handle character data events :)
sub characterData 
{
       my( $parseinst, $data ) = @_;
       #Just if there were CDATA this is how to process it...
       #if ( $tag eq "the_cdata_tag" ) {
       #       $data =~ s/\n|\t//g;
       #       print "$data";
       #}
}

#All other XML events :)
sub default 
{
       my( $parseinst, $data ) = @_;
       # you could do something here
}

###################################
#END XML EVENT DRIVEN FUNCTIONS
###################################

#Process eval of XML parsing output.
sub eval_xml
{

	my ( $eval_results ) = @_;
	# report any error that stopped parsing, or announce success
	if( $eval_results ) 
	{
    	$eval_results =~ s/at \/.*?$//s;               # remove module line number
    		die( "\nERROR in XML:\n$@\n");
    	#We could also ki
	} else 
	{
    	print STDERR "XML is well-formed\n";
	}

}


#################################################################
#Start parsing our XML output if there were no errors above.
#Stream based parsing uses subroutines triggered by XML events.
##################################################################

#Setup which function handles which event :)
$parser->setHandlers(      Start => \&startElement,
                           End => \&endElement,
                           Char => \&characterData,
                           Default => \&default,
                           );

#Open up the delete file that we will use create our list of email addresses to delete.
print "Processing file listing email addresses that could be deleted:\n  $delete_file\n\n";

open(DELETE_FILE, $delete_file) || die("Could not open delete file! $delete_file");
@delete_mailboxes=<DELETE_FILE>;
chomp(@delete_mailboxes);

#The last entry in the delete_mailboxes array needs to be --FILE--COMPLETE--  
#or we should assume the write script failed.
if ( $delete_mailboxes[-1] ne "--FILE--COMPLETE--" )
{
	die("The delete mailboxes file is not finished.  The last entry in the list should be --FILE--COMPLETE--.\nIt is $delete_mailboxes[-1]\n");
}


#Get the initial login token if we are not using an XML file for input...
if ( !$xml_file )
{
		
	#Check to see if we are passing the token in else generate a new one.
	if ( $in_token )
	{
		print "Use token provided via option input.\n";
		$token=$in_token;
	}
	else
	{
		print "Generating a new token.\n";
		$token=get($token_get_url);
		die "Couldn't get token!" unless defined $token;
	}
	
	print "Pulling down account data as XML from RedCondor.\n\n";
	#Get the full XML doc...
	$xml_out = get( $dashboard . '/api/mailbox/' . $domain . '/mailbox/list?domain=' . $domain . '&token=' . $token );
	die "Couldn't get XML output!" unless defined $xml_out;
	#Write the current settings for email user out to a file before starting the delete process.
	print "Writing out current email user account information.\n\n";
	

	
	#We are parsing the output variable retrieved using LWP above
	print "Parsing the XML to build an array out of the current RedCondor accounts.\n\n";
	#Note that we are using eval in order to handle the errors on our own VS letting Parse decide when the script should die 
	eval{ $parser->parse($xml_out); };  #If you want to parse through a variable or directly from the web
	eval_xml($@);
}
else
{                          
	#Stream through the file    
	print "Parsing the XML to build an array out of the current RedCondor accounts.\n\n";
	#Note that we are using eval in order to handle the errors on our own VS letting Parse decide when the script should die 
	eval { $parser->parsefile($xml_file); };  #If you want to parse a file
	eval_xml($@);
}




#The final delete list should consist of every email address in RedCondor that is also 
#in the array built from the file passed in the $delete_file variable.
print "\nBuild array of emails that do exist in RedCondor that are in the delete list.\n\n";
my $lc = List::Compare->new( { lists=> [ \@redcondor_mailboxes, \@delete_mailboxes], unsorted => 1, } );
@delete_list = $lc->get_intersection;

#SIMPLE STUFF FOR DELETING

#Loop through the delete list and start waxing those bad accounts!
my $current_email = '';

print scalar(@redcondor_mailboxes) . " Mailboxe(s) on RedCondor.\n";
print scalar(@delete_mailboxes) . " Mailboxe(s) in our delete file.\n";
print scalar(@delete_list) . " Mailboxe(s) will be deleted.\n";

print "Begin writing XML output for delete commandds.\n\n";



#Begin generating, outputting and processing the XML content
push(@xml_out_file_contents, '<configuration version="2.2">' ."\n");
push(@xml_out_file_contents, '  <domain name="' . $domain . '" >' . "\n");

foreach $current_email ( @delete_list )
{
    #print "The following emails will attempt to be deleted:\n";
	#print "################################################\n";
	#print $current_email . "\n";
	#Write out the delete account informations
	#Strip out the domain name.  The XML out will fail if this is included.
	$current_email =~ s/\@$domain//g;
	push(@xml_out_file_contents, '   <mailbox name="' . $current_email . '" delete="true"></mailbox>' . "\n");
	
	#Print out the equivalent API URL that is generated by the script
	#print $dashboard . '/api/mailbox/delete?token=' . $token . '&email=' . $current_email . " Results: \n"; 
	#The actual call to the web based API to delete the account...
	#print get( $dashboard . '/api/mailbox/delete?token=' . $token . '&email=' . $current_email ); 
	#print "\n";
}

push(@xml_out_file_contents, '  </domain>' . "\n");
push(@xml_out_file_contents, '</configuration>' . "\n");

#Open file we will be writting the output to
open (MYFILE, ">$xml_out_file")
	or die "cannot open xml_out: $xml_out_file $!";
foreach my $write_it ( @xml_out_file_contents )	
{
	print MYFILE $write_it;
}
close (MYFILE);

#Post the results thus deleting the accounts :)
my $url=$dashboard . '/api/config/upload?token=' . $token . '&update=true';
my $ua  = LWP::UserAgent->new();
$ua->agent("NRAO-Newsletter-Sub/0.01 "); # set the HTTP 'browser' type  
my $response = $ua->post( $url, 
 			Content_Type => 'form-data',
            Content => [ data =>  [ "$xml_out_file" ] ]
           );
           
#my $response = $ua->request($res);

if ($response->is_success()) {
    print "OK: ", $response->content;
} else {
    print $response->as_string;
}
