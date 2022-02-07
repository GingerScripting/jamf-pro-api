#!/bin/bash

#looks for classes in jamf with the criteria, adds them to a CSV, and then deletes them

#Add the Jamf Pro URL and user credentials for an account that has permission to delete classes here if you don't want to be prompted for them.
jssUser=
jssPassword=
jssURL=

#Enter the search term you want to use for deleting classes with no quotes. If nothing is entered here, you will be prompted.
searchCriteria=

#You can also uncomment this line if you want the script to read which jamf server the computer it is running on connects to.
#jssURL=$(/usr/bin/defaults read ~/Library/Preferences/com.jamfsoftware.jss.plist url)

xpath() {
    # the xpath tool changes in Big Sur 
    if [[ $(sw_vers -buildVersion) > "20A" ]]; then
        /usr/bin/xpath -e "$@"
    else
        /usr/bin/xpath "$@"
    fi
}

if [ -z $jssURL ]; then
	echo "Please enter your Jamf Pro URL:"
	read -r jssURL
fi 

if [ -z $jssUser ]; then
	echo "Please enter the Jamf Pro username for an account that has permission to delete classes:"
	read -r jssUser
fi 

if [ -z $jssPassword ]; then 
	echo "Please enter the Jamf Pro password for account: $jssUser:"
	read -r -s jssPassword
fi

echo "Logging in to $jssURL as $jssUser"

if [ -z $searchCriteria ]; then 
	echo "Please enter the search criteria you would like to use (example: S1 for Semester 1 classes). If you want to delete ALL classes, leave this blank and press enter:"
	read -r searchCriteria
fi


#get currently logged in user
loggedInUser=$( scutil <<< "show State:/Users/ConsoleUser" | awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}' )
echo "Checking for CSV file on $loggedInUser desktop..."

reportType=jamfClasses

if [ -f /Users/"$loggedInUser"/Desktop/"$reportType".csv ]; then
	echo "CSV already exists. Overwriting..."
	rm -rf /Users/"$loggedInUser"/Desktop/"$reportType".csv
fi

echo "Creating CSV..."
touch /Users/"$loggedInUser"/Desktop/"$reportType".csv

#creating temporary file if it doesn't exist already
if [ -f /tmp/classesToDelete.txt ]; then
	rm -rf /tmp/classesToDelete.txt
fi

touch /tmp/classesToDelete.txt

#adds header fields to the CSV
echo "Class ID","Class Name","Deletion" >> /Users/"$loggedInUser"/Desktop/"$reportType".csv

removeClasses() {
	echo "Deleting Classes..."
	while read -r classID; do
  	echo "Deleting class with ID $classID"
  	curl -X DELETE -H "Accept: application/xml" -s -u "${jssUser}":"${jssPassword}" ${jssURL}/JSSResource/classes/id/$classID
	done </tmp/classesToDelete.txt
	echo "Complete."
}

#loops through all classes currently in jamf
classIDs=($(/usr/bin/curl -X GET -H "Accept: application/xml" -s -u "${jssUser}":"${jssPassword}" ${jssURL}/JSSResource/classes | xpath "/classes/class/id" 2> /dev/null | awk -F'</?id>' '{for(i=2;i<=NF;i++) print $i}'))
counter=0
for id in "${classIDs[@]}"; do
	OLDIFS=$IFS
	IFS=$'\n'
	#gets the name of the class and looks for search criteria in the name
	className=$(curl -X GET -H "Accept: application/xml" -s -u ${jssUser}:${jssPassword} "${jssURL%/}"/JSSResource/classes/id/$id | /usr/bin/awk -F '<name>|</name>' '{print $2}')
		if echo "$className" | grep  -q "$searchCriteria"; then
			echo "$className will be deleted. Adding to CSV."
			echo "$id" >> /tmp/classesToDelete.txt
			counter=$((counter + 1))
			echo "$id","$className","Deleted" >> /Users/"$loggedInUser"/Desktop/"$reportType".csv
		else 
			echo "$className will not be deleted. Adding to CSV."
			echo "$id","$className","Remaining" >> /Users/"$loggedInUser"/Desktop/"$reportType".csv
		fi
done
read -p "All classes have been checked. $counter will be deleted. Check the CSV on your desktop for details. Type DELETE when you are ready to continue." choice
	case "$choice" in 
  	DELETE ) 
  		removeClasses;;
 	* ) 
 		echo "Classes will not be deleted. Exiting..."
 		sleep 2
  		exit 0;;
	esac
	
IFS=$OLDIFS
rm -rf /tmp/classesToDelete.txt
