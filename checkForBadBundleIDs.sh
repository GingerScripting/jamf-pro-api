#!/bin/bash

#This script goes through all of the mobile device applications in your Jamf Pro instance and checks for bad bundle IDs
#This usually happens when an app has been removed from the App Store
#jq is required for this script to run

#gets the jamf URL the computer you are running the script on uses to connect
#comment this section out and use the next one instead if you get errors when trying to connect
jssURL=$(/usr/bin/defaults read ~/Library/Preferences/com.jamfsoftware.jss.plist url)

#hardcode the actual JSS URL here and un-comment if you get errors when trying to connect
#jssURL=

#prompts for username and password
#comment this section out and use the next one instead if you want to hardcode credentials

if [ -z $jssUser ]; then
	echo "Please enter your JSS username:"
	read -r jssUser
fi 

if [ -z $jssPassword ]; then 
	echo "Please enter JSS password for account: $jssUser:"
	read -r -s jssPassword
fi

#hardcode credentials here if you don't want to be prompted
#jssUser=
#jssPassword=

echo "Logging in as $jssUser"

#gets logged in user to put the csv on their desktop
#comment this out and manually add a username if this is going to be run as root (through LaunchDaemon or jamf for example)
loggedInUser=$( scutil <<< "show State:/Users/ConsoleUser" | awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}' )

#hardcode username here if you aren't getting the logged in user automatically
#loggedInUser=

todaysDate=$(date +"%m-%d-%Y")

xpath() {
    # the xpath tool changes in Big Sur 
    if [[ $(sw_vers -buildVersion) > "20A" ]]; then
        /usr/bin/xpath -e "$@"
    else
        /usr/bin/xpath "$@"
    fi
}

#checks for existence of csv and deletes it if necessary
echo "Creating New CSV..."
if [ -f /Users/"$loggedInUser"/Desktop/"$todaysDate"\badApps.csv ]; then
	echo "CSV already exists. Overwriting..."
	rm -rf /Users/"$loggedInUser"/Desktop/"$todaysDate"\badApps.csv
fi
/usr/bin/touch /Users/"$loggedInUser"/Desktop/"$todaysDate"\badApps.csv
echo "Bundle ID" >> /Users/"$loggedInUser"/Desktop/"$todaysDate"\badApps.csv

#loop through app ID numbers and get their bundle IDs
echo "Checking Jamf bundle IDs against the App Store bundle IDs. This may take a while..."
bundleIDs=($(/usr/bin/curl -X GET -H "Accept: application/xml" -s -u "${jssUser}":"${jssPassword}" ${jssURL}/JSSResource/mobiledeviceapplications | xpath "//bundle_id" 2> /dev/null | awk -F'</?bundle_id>' '{for(i=2;i<=NF;i++) print $i}'))

#checks bundle IDs against the App Store and puts them in a CSV if they do not exist
#jq needs to be installed for this section to work
for bundleID in "${bundleIDs[@]}"; do
	iTunesURL="http://itunes.apple.com/lookup?bundleId=${bundleID}"
	#echo "$iTunesURL"
	searchResults=$(curl -s "$iTunesURL" | jq '[.[] ] | .[0]')
	#echo "$searchResults"
	if [ "$searchResults" != 1 ]; then
	echo "$bundleID" >> /Users/"$loggedInUser"/Desktop/"$todaysDate"\badApps.csv
	fi
done
echo "Complete. A CSV has been created on your desktop with today's date with Bundle IDs of all apps not found in the App Store."
