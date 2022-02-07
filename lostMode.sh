#!/bin/bash

#sends the Enable Lost Mode command to all devices in an advanced search

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

echo "Please enter the ID number for the advanced search that you would like to send the Lost Mode command to:"
read -r searchID

deviceNumbers=($(/usr/bin/curl -X GET -H "Accept: application/xml" -s -u "${jssUser}":"${jssPassword}" ${jssURL}/JSSResource/advancedmobiledevicesearches/id/"$searchID" | xpath "//mobile_device//id" 2> /dev/null | awk -F'</?id>' '{for(i=2;i<=NF;i++) print $i}'))

setLostMode(){

goodXML="<mobile_device_command>
    <general>
        <command>EnableLostMode</command>
        <lost_mode_message>[ENTER MESSAGE HERE]</lost_mode_message>
        <lost_mode_phone>[ENTER PHONE NUMBER HERE]</lost_mode_phone>
        <lost_mode_footnote>[ENTER FOOTNOTE HERE]</lost_mode_footnote>
        <always_enforce_lost_mode>true</always_enforce_lost_mode>
        <lost_mode_with_sound>true</lost_mode_with_sound>
    </general>
    <mobile_devices>
        <mobile_device>
            <id>$device</id>
        </mobile_device>
    </mobile_devices>
</mobile_device_command>"

curl -X POST \
  ${jssURL}/JSSResource/mobiledevicecommands/command/EnableLostMode \
    --user "$jssUser":"$jssPassword" \
    --header "Content-Type: text/xml" \
    --request POST \
    --data "$goodXML"
}

for device in "${deviceNumbers[@]}"; do
#	echo "Device number is $device"
	setLostMode
	echo "Lost mode set on device number $device"
done
