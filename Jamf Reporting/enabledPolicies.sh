#!/bin/bash

#This script creates a CSV with all the policies in your Jamf Pro instance and lets you know if they are enabled or not

#Add your credentials and Jamf Pro URL here if you don't want to be prompted for them. This is also necessary if you are running the script as root (jamf or LaunchDaemon)
jssUser=
jssPassword=
jssURL=

#You can also uncomment this line if you want the script to read which jamf server the computer it is running on connects to.
#jssURL=$(/usr/bin/defaults read ~/Library/Preferences/com.jamfsoftware.jss.plist url)


if [ -z $jssURL ]; then
	echo "Please enter the JSS URL:"
	read -r jssURL
fi 

if [ -z $jssUser ]; then
	echo "Please enter your JSS username:"
	read -r jssUser
fi 

if [ -z $jssPassword ]; then 
	echo "Please enter JSS password for account: $jssUser:"
	read -r -s jssPassword
fi

echo "Logging in to $jssURL as $jssUser"

xpath() {
    # the xpath tool changes in Big Sur
    if [[ $(sw_vers -buildVersion) > "20A" ]]; then
        /usr/bin/xpath -e "$@"
    else
        /usr/bin/xpath "$@"
    fi
}

#gets logged in user to put the csv on their desktop - can also manually enter this
loggedInUser=$( scutil <<< "show State:/Users/ConsoleUser" | awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}' )
echo "The currently logged in user is $loggedInUser. Creating CSV file on the desktop..."

reportType=enabledPolices

touch /Users/"$loggedInUser"/Desktop/"$reportType".csv

#adds header fields to the CSV
echo "Policy ID","Policy Name","Enabled" >> /Users/"$loggedInUser"/Desktop/"$reportType".csv

policyIDs=($(/usr/bin/curl -X GET -H "Accept: application/xml" -s -u "${jssUser}":"${jssPassword}" ${jssURL}/JSSResource/policies | xpath "/policies/policy/id" 2> /dev/null | awk -F'</?id>' '{for(i=2;i<=NF;i++) print $i}'))
for id in "${policyIDs[@]}"; do
	OLDIFS=$IFS
	IFS=$'\n'
	echo "Checking policy number $id"
	policyName=$(curl -X GET -H "Accept: application/xml" -s -u ${jssUser}:${jssPassword} "${jssURL%/}"/JSSResource/policies/id/$id/subset/general | /usr/bin/awk -F '<name>|</name>' '{print $2}')
	enabled=$(/usr/bin/curl -X GET -H "Accept: application/xml" -s -u ${jssUser}:${jssPassword} "${jssURL%/}"/JSSResource/policies/id/$id | /usr/bin/awk -F '<enabled>|</enabled>' '{print $2}')
	echo "$id","$policyName","$enabled" >> /Users/"$loggedInUser"/Desktop/"$reportType".csv	
done
IFS=$OLDIFS

echo "Complete. A CSV file has been created on the desktop showing which policies are enabled."
