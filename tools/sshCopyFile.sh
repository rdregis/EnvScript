#!/bin/bash

version=1.0.0

sendConfir=0
sendFile=
sendHost=
sendPort=
userDest=$(id -nu)

showHelp() {
    # `cat << EOF` This means that cat should stop reading when EOF is detected
    cat <<EOF

Copy files to destination server: $version
Usage: $0 [ -h ] | [ -sc ] [ -u <user dest> ] <file to send>  <host> [ <port> ] 

-h,  -help,        	--help          	Display help

<file name to send>:          		File name to be copied
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

        -sc | --scp)
            sendConfir=1
            ;;

        -u | --user)
            shift
            userDest=$1
            ;;

        *)
            if [ ! -z "$sendFile" ]; then
                doDisplay 1 "Invalid additional parameter: $1"
                showHelp
                exit
            fi
            sendFile=$1
            shift
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

copyFile() {
    local file=$1
    local user=$2
    local host=$3
    local port=$4
    local destFile=$5

    doDisplay 6 "Copying file[$(basename $file)] from $host:$port ...."

    if [ -z "$destFile" ]; then
        destFile=$(basename $file)
    fi

    #doDisplay 6 "scp -P $port $user@$host:$file $destFile"
    if [ $sendConfir -eq 1 ]; then
        echo date >$file.scf
        doExecute "scp -P $port $file $file.scf $user@$host:" # >/dev/null #2>&1
        rm $file.scf
    else
        doExecute "scp -P $port $file $host:$destFile" # >/dev/null #2>&1
    fi

    if [ $? -ne 0 ]; then
        doDisplay 1 "Error on scp copying file: $file"
        exit
    fi
}

#"**************************************************************************************************"
#" Main
#"**************************************************************************************************"

getRunParameters $*

if [ ! -f "$sendFile" ]; then
    doDisplay 3 "==> Invalid copy file parameter: $sendFile"
    showHelp
fi

if [ -z "$sendHost" ] || [ -z "$sendPort" ]; then
    doDisplay 3 "==> Invalid send host or port parameter: $sendHost:$sendPort"
    showHelp
fi

count=$(nc -z -v -w5 $sendHost $sendPort 2>&1 | grep -c succeeded)
if [ $count -eq 0 ]; then
    doDisplay 3 "$(nc -z -v -w5 $sendHost $sendPort 2>&1)"
    showHelp
fi

copyFile $sendFile $userDest $sendHost $sendPort
