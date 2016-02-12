#!/usr/bin/perl -w

use strict;
use lib "/usr/local/lib";
use warnings;
use CLI; #For Communigate
use DBI; #For Oracle Connections
use List::Compare; #For easy array matching and sorting
use Time::Local;
use Date::Calc qw(Today Days_in_Month Add_Delta_Days);
use Date::Parse;
use Getopt::Long;


############################
#Validate command options

my ( $out_file ) = ( '' );
GetOptions(
           "out_file=s" => \$out_file   #File to write invalid email addresses out to
          );
          
if ( !$out_file )
{
	die("Please specify an output file to write the doomed email addresses to like so\nget_delete_mailboxes.pl --out_file /tmp/blargh.txt \n\n"); 
}

############################
#  Oracle Config params
############################

my $ispora_db = 'dbi:Oracle:database';
my $ispora_user = 'user';
my $ispora_pass = 'password';
my $ispora_query = <<_SQL_;
    SELECT LOWER(username) 
    FROM rad_users
    WHERE (
              -- The delete_date field is 6 months after the date the account was removed
              -- This will get all removed users, with a 7 day "grace period"
              account_status = 'Removed'
              AND ADD_MONTHS(delete_date, '-6') < SYSDATE - INTERVAL '7' DAY
          ) OR (
              account_status = 'Reserved'
          )
_SQL_

# Number of days after which to consider an account "Dormant", and should be purged from mail gateway 
our $CNF_DORMANT_DAYS = 180;

$ENV{'ORACLE_HOME'}     = '/usr/lib/oracle/10_2';
$ENV{'LD_LIBRARY_PATH'} = '/usr/lib/oracle/10_2';
$ENV{'TNS_ADMIN'} = '/usr/lib/oracle/10_2/admin/NETWORK';



############################
#  Communigate Config params
############################

my (%cg_all_users, %postini_users, $nbr_added, $nbr_deleted, @cg_active_emails,@cg_dormant_emails,@cg_alias_emails, $my_alias);

my $cg_server   = "cg_host";
my $cg_username = "cg_user";
my $cg_password = "password"";
my $cg_domain   = "domain.com";


my $DEBUG = 1;

our $CNF_CURL_CMD = '/usr/bin/curl -s';

our $CNF_REJECT_TEXT = <<END;
Your message was not delivered because this account has been disabled due to
prolonged inactivity.  The account will be re-enabled immediately when this user
logs into his account.
END

# Limit CG GetAccountInfo calls, since they're slow; for dev only; 0 to disable
our $CNF_DEV_LIMIT_CG = 0;

# Get list of removed/reserved users from ISP Oracle,
# even if not the last-1 or last day of the month
our $CNF_FORCE_REMOVE_SYNC = 0;


###############################################
#Put your subs here guys
###############################################


#######################
=head2 get_forward
Input: Username whose forwarding target you want to get,
       existing_rules arrayref (from GetAccountSettings call's {Rules} key)
Returns: Arrayref of status, then forwarding address, or blank
Query CG for forwarding target

Example:
$result = get_forward('tedtest', $existing_rules);
=cut

sub get_forward 
{
    my $email = shift;
    my $existing_rules = shift;
    my ($target, @rules, @response);

    if (defined($existing_rules) && ref $existing_rules) 
    {
        @rules = @$existing_rules;
        if (@rules) 
        {
            my @redirect_rule = grep { $_->[1] eq "#Redirect" && $_->[0] eq '1' } @rules;
            $target = $redirect_rule[0][3][0][1];
        }
        @response = ('SUCCESS', $target);
    }
    return \@response;
};

###################################################
#  Build array of Radius users that we can delete
####################################################

# Execute only on the last-1 or last day of the month
# Since this executes twice a day, this routine will run
# 4 times, ensuring that it gets done even if this script
# is down for a day.

# Today() returns an array of Y, M, D
# Translation: today's day >= last-1 day of this month
my $purge_removed_today = (Today())[2] >= Days_in_Month( (Today())[0,1] ) - 1;

my %removed_users = ();

print "Connecting to ISP Oracle server\n";
my $dbh = DBI->connect($ispora_db, $ispora_user, $ispora_pass,
                      { AutoCommit => 0, RaiseError => 1 });
    
print "Getting list of removed/reserved users\n";
# Fetch all rows from the Oracle query into a list, then set the
# hash keys of %removed_users to each of the list elements
my $rad_user_results = $dbh->selectcol_arrayref($ispora_query);

my @rad_delete_emails = ();
my $rad_user;
#The array we will use to combine with the CG dormant list...
#Build Radius user delete list thing array
foreach  $rad_user ( @$rad_user_results )
{
	push ( @rad_delete_emails, $rad_user . '@' . $cg_domain );
}

#Disconnect the database connection if you can't tell
$dbh->disconnect();


#################################################
#  Build arrays of CG users
#################################################

print "Connecting to CG server\n" if $DEBUG;

# Connect to CG server
our $cli = new CGP::CLI( { PeerAddr => $cg_server,
                          PeerPort => 106,
                          login    => $cg_username,
                          password => $cg_password,
                      } )
          || die "Could not connect to CommuniGate: $CGP::ERR_STRING\n";

print "Getting CG account list\n" if $DEBUG;

# The lists of accounts and aliases are used when deleting Postini accounts

# ListAccounts returns a hash reference, with usernames as the keys
my $cg_acct_ref = $cli->ListAccounts( $cg_domain )
    || die "Can't list CG accounts: " . $cli->getErrMessage . "\n";

# Dereference hash
%cg_all_users = %$cg_acct_ref;

# Put CG users in a hash
# Get user's aliases; put them in a hash (used when deleting Postini accounts)
print "Limiting CG GetAccountInfo calls to $CNF_DEV_LIMIT_CG -- dev only\n" if $CNF_DEV_LIMIT_CG;

#Convert the days into seconds for the allowed dormant setting.
my $dormant_cutoff_sec = time() - ($CNF_DORMANT_DAYS * 86400);
my $nbr = 0;

print "Process retrieved list...\n";

#Process accounts
for my $this_cg (keys %cg_all_users) {

    #$cli->setDebug(1);
    # Get the account's last login time, settings, and forwarder rule
    my $last_login = $cli->GetAccountInfo("$this_cg\@$cg_domain", 'LastLogin');
    warn "Can't GetAccountInfo for $this_cg: " . $cli->getErrMessage unless ($cli->isSuccess);
    my $account_settings = $cli->GetAccountSettings("$this_cg\@$cg_domain");
    warn "Can't GetAccountSettings for $this_cg: " . $cli->getErrMessage unless ($cli->isSuccess);
    my $existing_forward = get_forward($cli, "$this_cg\@$cg_domain", $account_settings->{Rules});
    
    # Fixup $last_login format so we can parse it
    # This changes $last_login to be a format we can parse with Date::Parse::str2time (ISO-8601), below
    # Note: Not exactly sure what timezone CG is storing this time in; could be UTC or local
    # Example of starting value: "#T31-05-2007_01:27:07"
    if ($last_login =~ /^#T/) {
        $last_login =~ /^#T(\d{2})-(\d{2})-(\d{4})_(.+)$/;
        $last_login = "$3:$2:$1T$4";
    }
    my $last_login_sec = Date::Parse::str2time($last_login) || 0;   # e.g., "Thu, 24 May 2007 22:00:56 +0000"

    # If account has not been used in X months, and it's not forwarding elsewhere, add it to the dormant user list
    # Else, it goes on the "active users" list
    if ( (! $last_login || $last_login_sec < $dormant_cutoff_sec) && (! defined $existing_forward->[1] || $existing_forward->[1] eq ''))
    {
        push( @cg_dormant_emails, $this_cg . '@' . $cg_domain );
    } 
    else 
    {
        push( @cg_active_emails, $this_cg . '@' . $cg_domain );

        # Add this account's aliases to the alias hash, so they don't get deleted below
        # GetAccountAliases returns array ref
        if (my $alias_ref = $cli->GetAccountAliases("$this_cg\@$cg_domain") ) 
        {
             
             foreach $my_alias ( @$alias_ref )
             {
             	push( @cg_alias_emails, $my_alias . '@' . $cg_domain );
             }
            
        } 
        else 
        {
            warn "Can't GetAccountAliases for $this_cg: " . $cli->getErrMessage unless ($cli->isSuccess);
        }    
    }

    # limit the number of accounts to query -- for dev only
    if ($CNF_DEV_LIMIT_CG) {
        last if ($nbr == $CNF_DEV_LIMIT_CG);
        $nbr++;
    }
}

##################################
# OUTPUT TIME BABY!
##################################

print "\n#################################################################\n";
print "There are " . scalar(@rad_delete_emails) . " Radius Users that can be deleted.\n";
print "#################################################################\n\n";
print "\n#################################################################\n";
print "There are " . scalar keys(%cg_all_users) . " CommuniGate users\n";
print "#################################################################\n\n";
print "There are " . scalar(@cg_active_emails) . " active email addresses in the array cg_active_emails...\n";
print "There are " . scalar(@cg_dormant_emails) . " dormant email addresses in the array cg_dormant_emails...\n";
print "There are " . scalar(@cg_alias_emails) . " alias email addresses in the array cg_alias_emails...\n\n";

my $lc_poo = List::Compare->new( { lists=> [ \@cg_dormant_emails, \@rad_delete_emails], unsorted => 1, } );
my @lc_poo = $lc_poo->get_intersection;
print scalar(@lc_poo) . " Emails in both Rad remove and CG lists \n\n";


#Get the union ( all in both ) of the accounts that need to be deleted according to radius as well as communigate.
my $lc_delete = List::Compare->new( { lists=> [ \@cg_dormant_emails, \@rad_delete_emails], unsorted => 1, } );
my @lc_delete = $lc_delete->get_union;

#Remove any of the aliases we identified in the cg_alias_email and generate a final clean array
my $lc_delete_clean = List::Compare->new( { lists=> [ \@lc_delete, \@cg_alias_emails], unsorted => 1, } );
my @lc_delete_clean = $lc_delete_clean->get_unique;

print scalar(@lc_delete_clean) . " Emails in the final list...\n\n";

#Push the value that the file pickup job should look for on the last line...";
push( @lc_delete_clean, "--FILE--COMPLETE--" );

#Create the final output file to be picked up by the RedCondor cleanup script
#named redcondor_mailboxes.pl.
open (MYFILE, ">$out_file");
	foreach my $file_out ( @lc_delete_clean )
	{
		print MYFILE "$file_out\n";
	}
close (MYFILE);
