#!/bin/bash

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

xpath() {
    # the xpath tool changes in Big Sur
    if [[ $(sw_vers -buildVersion) > "20A" ]]; then
        /usr/bin/xpath -e "$@"
    else
        /usr/bin/xpath "$@"
    fi
}


echo "Logging in to $jssURL as $jssUser"

#gets logged in user to put the csv on their desktop
loggedInUser=$( scutil <<< "show State:/Users/ConsoleUser" | awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}' )
echo "The currently logged in user is $loggedInUser. Creating CSV file on the desktop..."

#creates the two necessary files 
touch /tmp/output.txt
touch /Users/"$loggedInUser"/Desktop/Usage.csv

#adds header fields to the CSV
echo "Computer Name","Logins During Target Time" >> /Users/"$loggedInUser"/Desktop/Usage.csv

#loops through all computer IDs in the advanced computer search indicated
computerIDs=($(/usr/bin/curl -X GET -H "Accept: application/xml" -s -u "${jssUser}":"${jssPassword}" ${jssURL}/JSSResource/advancedcomputersearches/id/[ID Number of Advanced Search] | xpath "/advanced_computer_search/computers/computer/id" 2> /dev/null | awk -F'</?id>' '{for(i=2;i<=NF;i++) print $i}'))
for id in "${computerIDs[@]}"; do
#prints the ID number it is working on
echo "Checking computer with ID $id"
	#gets the name of the device associated with the ID number
	computerName=$(curl -X GET -H "Accept: application/xml" -s -u ${jssUser}:${jssPassword} "${jssURL%/}"/JSSResource/computers/id/$id/subset/general | awk -F '<name>|</name>' '{print $2}')
	#loops through all of the events in the computer's history and puts them in the txt file (so they can be parsed as text)
	computerHistory=$(/usr/bin/curl -X GET -H "Accept: application/xml" -s -u ${jssUser}:${jssPassword} "${jssURL%/}"/JSSResource/computerhistory/id/$id/subset/ComputerUsageLogs | xpath "/computer_history/computer_usage_logs/usage_log" 2> /dev/null | awk -F'</?usage_log>' '{for(i=2;i<=NF;i++) print $i}' > /tmp/output.txt)
	for command in "${computerHistory[@]}"; do
	#looks through the command text for logins in November between 1 and 2 pm CST
	loginNumber=$(grep -c '<event>login</event><username>........</username><date_time>2020/11/[0-1][0-9] at [7-8]:.. PM' /tmp/output.txt)
	echo "$computerName: $loginNumber login(s)"
	echo "$computerName","$loginNumber" >> /Users/"$loggedInUser"/Desktop/Usage.csv
	done
done

#cleans up temporary text file
rm /tmp/output.txt

echo "Complete. A CSV has been created on the desktop with computer usage."
