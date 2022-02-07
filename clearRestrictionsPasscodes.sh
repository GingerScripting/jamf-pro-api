#!/bin/bash

#sends the Clear Restrictions Passcode command to all devices in an advanced search

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

echo "Please enter the ID number for the advanced search that you would like to send the Clear Passcode command to:"
read -r searchID

deviceNumbers=($(/usr/bin/curl -X GET -H "Accept: application/xml" -s -u "${jssUser}":"${jssPassword}" ${jssURL}/JSSResource/advancedmobiledevicesearches/id/"$searchID" | /usr/bin/xpath "//id" 2> /dev/null | awk -F'</?id>' '{for(i=2;i<=NF;i++) print $i}'))

clearRestrictionsPasscode(){

goodXML="<mobile_device_command>
    <general>
        <command>ClearRestrictionsPassword</command>
    </general>
    <mobile_devices>
        <mobile_device>
            <id>$device</id>
        </mobile_device>
    </mobile_devices>
</mobile_device_command>"

curl -X POST \
  ${jssURL}/JSSResource/mobiledevicecommands/command/ClearRestrictionsPassword \
    --user "$jssUser":"$jssPassword" \
    --header "Content-Type: text/xml" \
    --request POST \
    --data "$goodXML"
}

for device in "${deviceNumbers[@]}"; do
	clearRestrictionsPasscode
  echo "Restrictions cleared on device number $device"
done
