#!/bin/bash

#Wrapper around get deletion list and deleltion script.

day_of_week=`date +%u`

script_dir="/usr/local/hargray_scripts/edgewave_scripts"
email="email@email.com"
password="password"
dashboard="http://dashboard"
delete_xml="$script_dir/XML/delete_accounts$day_of_week.xml"
delete_file="$script_dir/TXT/delete$day_of_week.out"
domain="domain.com"

#Uncomment if you want to generate and pass the token into delete_mailboxes.pl script.
#You really only want to do that if you want to use the same token in other scripts.
#token_get_url="/api/login?email=$email&password=$password"
token=`curl $dashboard$token_get_url`


echo $save_xml

#Get list of "BAD" users from Communigate and Radius
$script_dir/get_delete_mailboxes.pl --out_file $delete_file

#Use the list generated above to delete the unwanted RedCondor users
$script_dir/delete_mailboxes.pl --domain $domain --email $email --password $password --dashboard $dashboard --delete_file $delete_file --xml_out $delete_xml

#Clean up the day's delete email list to make sure we are getting the current
mv $delete_file $delete_file.done

#We are doing the curl using LWP within the delete_mailboxes script.  It just seemed neater.
#if [ -f $delete_xml ]
#then
#	curl -F "data=@$delete_xml" "$dashboard/api/config/upload?token=$token&account=a58ca22b-657a-4a47-a40d-e688a3b4d168&update=true" > result.xml
#fi

