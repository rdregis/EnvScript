#!/bin/bash

version=1.0.0

sendHost=
sendPort=
userDest=$(id -nu)

showHelp() {
    # `cat << EOF` This means that cat should stop reading when EOF is detected
    cat <<EOF

Access on destination server: $version
Usage: $0 [ -h ] | [ -u <user dest> ] <host> [ <port> ] 

-h,  -help,        	--help          	Display help

<user dest>:          		        User name of destination server
<host>:          		            Host name of server
<port>:	  		                    Port of server

	
Pre-requesits: 
    - send application or server must be installed and running
    - The destination server must be running ssh server
  
Notes:
    
EOF
    # EOF is found above and hence cat command stops reading. This is equivalent to echo but much neater when printing out.
    exit
}

doDisplay() {
    local color=$1
    shift
    local msg=$*
    echo "$(tput setaf $color)$msg $(tput sgr0)"
}

getRunParameters() {
    operation=send

    while [ ! -z "$1" ]; do
        case "$1" in
        -h | --help)
            showHelp
            exit 0
            ;;

        -u | --user)
            shift
            userDest=$1
            ;;

        *)
            cpyParam=$1
            if [ $(echo $cpyParam | grep -c ":") -eq 1 ]; then
                sendHost=$(echo $cpyParam | cut -d":" -f1)
                sendPort=$(echo $cpyParam | cut -d":" -f2)
            else
                sendHost=$1
                shift
                sendPort=$1
            fi

            ;;

        esac
        shift
    done
    shift

    if [ -z $sendPort ]; then
        sendPort=22
    fi

}

doExecute() {

    local command=$*

    doDisplay 6 "==> $command"
    $command

    exitStatus=$?

    if [ $exitStatus -ne 0 ]; then
        doDisplay 1 "*************************************************************"
        doDisplay 1 "* Error on execute $command"
        doDisplay 1 "*************************************************************"
        exit -1
    fi
}

accessServer() {

    local user=$1
    local host=$2
    local port=$3

    doDisplay 6 "Accessing server from $host ...."

    doExecute "ssh -p $port $user@$host" # >/dev/null #2>&1

    if [ $? -ne 0 ]; then
        doDisplay 1 "Error on scp copying file: $file"
        exit
    fi
}

#"**************************************************************************************************"
#" Main
#"**************************************************************************************************"

getRunParameters $*

if [ -z "$sendHost" ] || [ -z "$sendPort" ]; then
    doDisplay 3 "==> Invalid send host or port parameter: $sendHost:$sendPort"
    showHelp
fi

count=$(nc -z -v -w5 $sendHost $sendPort 2>&1 | grep -c succeeded)
if [ $count -eq 0 ]; then
    doDisplay 3 "$(nc -z -v -w5 $sendHost $sendPort 2>&1)"
    showHelp
fi

accessServer $userDest $sendHost $sendPort
