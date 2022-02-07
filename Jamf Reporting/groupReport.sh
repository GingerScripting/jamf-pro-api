#!/bin/bash

#This script creates a nice CSV of what groups are in use by which policies and profiles - handy for Jamf cleanup

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

#gets logged in user to put the csv on their desktop - can also manually enter this - add error checking to see if the file already exists and delete it
loggedInUser=$( scutil <<< "show State:/Users/ConsoleUser" | awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}' )
echo "The currently logged in user is $loggedInUser. Creating CSV file on the desktop..."

reportType=GroupReport

#creates the two necessary files - these should be variables 
#touch /tmp/output.txt
touch /Users/"$loggedInUser"/Desktop/"$reportType".csv
echo "File created. Adding data to CSV..."

OLDIFS=$IFS
IFS=$'\n'

#adds header fields to the CSV
echo "Type","Name","Scope" >> /Users/"$loggedInUser"/Desktop/"$reportType".csv

#loops through all computer IDs in the advanced computer search indicated
policyIDs=($(/usr/bin/curl -X GET -H "Accept: application/xml" -s -u "${jssUser}":"${jssPassword}" ${jssURL}/JSSResource/policies | xpath "/policies/policy/id" 2> /dev/null | awk -F'</?id>' '{for(i=2;i<=NF;i++) print $i}'))
for id in "${policyIDs[@]}"; do
	#prints the ID number it is working on - useful for error checking
	echo "Checking Policy ID Number $id"

	#gets the name of the device associated with the ID number
	policyName=$(curl -X GET -H "Accept: application/xml" -s -u ${jssUser}:${jssPassword} "${jssURL%/}"/JSSResource/policies/id/$id/subset/general | /usr/bin/awk -F '<name>|</name>' '{print $2}')

	scopeGroup1=($(/usr/bin/curl -X GET -H "Accept: application/xml" -s -u ${jssUser}:${jssPassword} "${jssURL%/}"/JSSResource/policies/id/$id | xpath "/policy/scope/computer_groups/computer_group/name" 2> /dev/null | awk -F'</?name>' '{for(i=2;i<=NF;i++) print $i}'))
		for policyGroup in "${scopeGroup1[@]}"; do
			echo "Policy","$policyName","$policyGroup" >> /Users/"$loggedInUser"/Desktop/"$reportType".csv
		done	
	
done

profileIDs=($(/usr/bin/curl -X GET -H "Accept: application/xml" -s -u "${jssUser}":"${jssPassword}" ${jssURL}/JSSResource/osxconfigurationprofiles | xpath "os_x_configuration_profiles/os_x_configuration_profile/id" 2> /dev/null | awk -F'</?id>' '{for(i=2;i<=NF;i++) print $i}'))
for id in "${profileIDs[@]}"; do
	echo "Checking Profile ID Number $id"
	#gets the name of the device associated with the ID number
	profileName=$(curl -X GET -H "Accept: application/xml" -s -u ${jssUser}:${jssPassword} "${jssURL%/}"/JSSResource/osxconfigurationprofiles/id/$id/subset/general | /usr/bin/awk -F '<name>|</name>' '{print $2}')
	scopeGroup2=($(/usr/bin/curl -X GET -H "Accept: application/xml" -s -u ${jssUser}:${jssPassword} "${jssURL%/}"/JSSResource/osxconfigurationprofiles/id/$id | xpath "/os_x_configuration_profile/scope/computer_groups/computer_group/name" 2> /dev/null | awk -F'</?name>' '{for(i=2;i<=NF;i++) print $i}'))
		for profileGroup in "${scopeGroup2[@]}"; do
			echo "Profile","$profileName","$profileGroup" >> /Users/"$loggedInUser"/Desktop/"$reportType".csv
		done	
done
IFS=$OLDIFS

echo "Complete. A CSV file has been created on the desktop showing which policies are using which package."
