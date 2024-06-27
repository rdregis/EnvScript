#!/bin/bash

version=1.1.0

shaTransferDir=~/.transferRPMFile
shaTransferFile=transferFile.sha
tarFile=transferFile.tar.gz
scriptNgrok=./tools/executeNgrok.sh
userDest=pharos
userOrigin= #rregis
userLocal=rregis
dirDest=/home/$userLocal

ngrokDir=~/ngrok
ngrokLog=$ngrokDir/ngrok.log

tmpScript=$(mktemp /tmp/transferRPMFile.sh.XXXXXX)
tmpRPMFile=$(mktemp /tmp/transferRPMFile.rpm.XXXXXX)

rpmFile=
ngrokHost=
ngrokPort=

showHelp() {
    # `cat << EOF` This means that cat should stop reading when EOF is detected
    cat <<EOF

Copy and instal rpm files: $version
On VM
    Usage: $0 [ -h ] | [ -t <rpm file name> <ngok host> <ngrok port> ] | [ -c <rpm file name> <ngok host> <ngrok port> ]
    Usage: $0 [ -h ] | [ -a <ngok host>:<ngrok port> ] 
On Pharos
    Usage: $0 [ -h ] | [ ] | [ -i <rpm file name>]

-h,  -help,        	--help          	Display help
-t  -transfer	       	--transfer   		Execute ngrok application to transfer rpm file
-c  -copy	       	--copy    		Copy rpm file from remote device
-i  -install	       	--install    		Install rpm file on destination device
-a  -access	       	--access    		Access on destination device

<rpm file name>:          		File name of rpm to be transfered and copied
<ngrok host>:                           Host name of ngrok server
<port>:	  		                Port of ngrok server

	
Pre-requesits: 
    - ngrok application must be installed on the origin system
    - Generate a token on https://dashboard.ngrok.com/auth/your-authtoken
        - Execute the following command: ngrok authtoken <token>
  
Notes:
    - To transfer: (executed in origin system)
        - Build the rpm file before execute this script
        - This script will execute ngrok application to transfer rpm file and will wait for copy file
        
    - To install (executed in destination system)
        - After copy file, this script will extract rpm file and install it
        - This will be restarted the system after install rpm file

EOF
    # EOF is found above and hence cat command stops reading. This is equivalent to echo but much neater when printing out.
}

doDisplay() {
    local color=$1
    shift
    local msg=$*
    echo "$(tput setaf $color)$msg $(tput sgr0)"
}

getRunParameters() {
    operation=ngrok

    if [ $# -eq 0 ]; then
        return
    fi

    while true; do
        case "$1" in
        -h | --help)
            showHelp
            exit 0
            ;;

        -t | --transfer)
            if [ $operation != "transferWindow" ]; then
                operation=transfer
            fi
            shift
            rpmFile=$1
            shift
            cpyParam=$1
            if [ $(echo $cpyParam | grep -c ":") -eq 1 ]; then
                ngrokHost=$(echo $cpyParam | cut -d":" -f1)
                ngrokPort=$(echo $cpyParam | cut -d":" -f2)
            else
                ngrokHost=$1
                shift
                ngrokPort=$1
            fi
            break
            ;;

        -c | --copy | -cw | --copyWindow)
            operation=copy
            if [ "$1" == "-cw" ] || [ ]"$1" == "--copyWindow" ]; then
                operation=copyWindow
            fi
            shift
            rpmFile=$1
            shift
            cpyParam=$1
            if [ $(echo $cpyParam | grep -c ":") -eq 1 ]; then
                ngrokHost=$(echo $cpyParam | cut -d":" -f1)
                ngrokPort=$(echo $cpyParam | cut -d":" -f2)
            else
                ngrokHost=$1
                shift
                ngrokPort=$1
            fi
            break
            ;;
        -a | --access)
            operation=access
            shift
            cpyParam=$1
            if [ $(echo $cpyParam | grep -c ":") -eq 1 ]; then
                ngrokHost=$(echo $cpyParam | cut -d":" -f1)
                ngrokPort=$(echo $cpyParam | cut -d":" -f2)
            else
                ngrokHost=$1
                shift
                ngrokPort=$1
            fi
            break
            ;;

        -i | --install)
            operation=install
            shift
            rpmFile=$1
            break
            ;;
        *)
            doDisplay 1 "Invalid parameter(S): $1"
            showHelp
            exit -2
            break
            ;;
        esac
        shift
    done
    shift

    if [ ! -z "$1" ]; then
        doDisplay 1 "Additional parameter: $1"
        showHelp
        exit
    fi
}

testParameter() {

    doDisplay 6 "==> Executing operation: $operation"
    case $operation in
    ngrok)
        if [ $(isDevicePharos) -eq 1 ]; then
            return 0
        fi
        doDisplay 3 "==> Operation : $operation can not executed in this device"
        ;;

    transfer | copy | copyWindow)
        if [ ! -z "$ngrokHost" ] && [ ! -z "$ngrokPort" ]; then
            count=$(nc -z -v -w5 $ngrokHost $ngrokPort 2>&1 | grep -c succeeded)
            if [ $count -eq 1 ]; then
                if [ -f "$rpmFile" ]; then
                    return 1
                fi
                doDisplay 3 "==> Invalid $operation file parameter: $rpmFile"
            fi
            doDisplay 3 "$(nc -z -v -w5 $ngrokHost $ngrokPort 2>&1)"
        fi
        doDisplay 3 "==> Invalid ngrok host or port parameter: $ngrokHost:$ngrokPort"
        ;;

    access)
        if [ ! -z "$ngrokHost" ] && [ ! -z "$ngrokPort" ]; then
            count=$(nc -z -v -w5 $ngrokHost $ngrokPort 2>&1 | grep -c succeeded)
            if [ $count -eq 1 ]; then
                return 1
            fi
            doDisplay 3 "$(nc -z -v -w5 $ngrokHost $ngrokPort 2>&1)"
            doDisplay 3 "==> Invalid ngrok host or port parameter: $ngrokHost:$ngrokPort"
        fi
        ;;

    install)
        if [ -f "$rpmFile" ]; then
            return 2
        fi
        doDisplay 3 "==> Invalid $operation file parameter: $rpmFile"
        ;;

    *)
        doDisplay 3 "Invalid operation: $operation"
        exit
        ;;
    esac

    showHelp
    exit
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

isDeviceVM() {

    local count=$(hostnamectl | egrep -e "Virtualization:" -e "Chassis: vm" | wc -l)

    if [ $count -gt 0 ]; then
        echo 1
        return
    fi

    echo 0
}

isDevicePharos() {
    local count=$(hostnamectl | egrep -e "Wind River Linux" -e "Chassis: laptop" | wc -l)

    if [ $count -gt 0 ]; then
        echo 1
        return
    fi

    echo 0
}

installPackage() {

    local package=$1

    local ret=$(snap list $package 2>/dev/null | grep -c $package)

    local sudoApp=sudo

    if [ $ret -eq 0 ]; then
        $sudoApp snap install $package
    fi
    $sudoApp snap refresh $package

    doDisplay 6 "Verifing installed package:... $package"
    doDisplay 5 "$(stat /var/lib/snapd/snaps/ngrok*.snap)"

}

execKill() {
    # find process onn pid list and kill him

    # Debug: To kill all, type in console the line bellow
    # for pid in $(ps -ef | grep "run_client_app" | awk '{print $2}'); do kill -9 $pid; done
    local agent=$1
    local wait=$2

    for pid in $(ps -ef | grep $agent | grep -v grep | sort -r -k 2 | awk '{print $2}'); do
        existTask=$(ps -ef | grep -v grep | grep -c $pid)
        if [ $existTask -eq 0 ]; then
            continue
        fi
        if [ $pid -ne $$ ]; then
            kill -2 $pid
            sleep $wait
            existTask2=$(ps -ef | grep -v grep | grep -c $pid)
            if [ $existTask2 -ne 0 ]; then
                sudo ill -9 $pid
                sleep 1
            fi
        fi
    done

}
killAll() {
    doDisplay 6 "Killing all process ..."

    # execKill "/tmp/ngrok.log" 1
    # execKill ngrok 5
}

trapPrepareTransferSignal() {
    doDisplay 6 "Capturing Ctrl-c signal ..."
    killAll

    sleep 1
    exit -1
}

prepareRPMTransfer() {
    local rpmFile=$1

    if [ ! -d "$shaTransferDir" ]; then
        mkdir -p $shaTransferDir
    fi

    cp $0 $shaTransferDir/$(basename $0)
    cp $scriptNgrok $shaTransferDir/$(basename $scriptNgrok)
    cp $rpmFile $shaTransferDir/$(basename $rpmFile)

    echo "Version: $version" >$shaTransferDir/$shaTransferFile
    echo "Script: $(
        cd -- "$(dirname "$0")" >/dev/null 2>&1
        pwd -P
    )/$(basename $0)" >>$shaTransferDir/$shaTransferFile

    local shaValue=$(sha512sum $shaTransferDir/$(basename $rpmFile))
    echo "shaRPM: $shaValue" >>$shaTransferDir/$shaTransferFile

    local shaValue=$(sha512sum $shaTransferDir/$(basename $0))
    echo "shaScriptTrf: $shaValue" >>$shaTransferDir/$shaTransferFile

    local shaValue=$(sha512sum $shaTransferDir/$(basename $scriptNgrok))
    echo "shaScriptNgk: $shaValue" >>$shaTransferDir/$shaTransferFile

    rm -rf $shaTransferDir/$tarFile

    doDisplay 6 "Creating tar file: $tarFile"
    tar -czvf $shaTransferDir/$tarFile -C $shaTransferDir . 1>/dev/null 2>/dev/null
    # if [ $? -ne 0 ]; then
    #     doDisplay 1 "Error on create tar file: $tarFile"
    #     exit
    # fi

    tar -tvf $shaTransferDir/$tarFile
}

checkMd5() {
    local tag=$1

    local shaFile=$(basename $(cat $shaTransferFile | grep $tag: | head -1 | tr -s " " | cut -d" " -f3))
    local shaValue=$(cat $shaTransferFile | grep $tag: | head -1 | cut -d" " -f2)

    doDisplay 6 "Checking sha512sum  file: [$shaFile] ...."

    echo "$shaValue  $shaFile" | sha512sum --check >/dev/null

    if [ $? -ne 0 ]; then
        doDisplay 1 "Error on sha512sum  file: $shaFile"
        exit
    fi
}

extractRPMFile() {
    local tarFile=$1

    doExecute tar -xzf $tarFile
    doExecute tar -tvzf $tarFile

    checkMd5 shaRPM
    checkMd5 shaScriptTrf
    checkMd5 shaScriptNgk

}

installRPMFile() {
    local rpmFile=$1

    doDisplay 6 "Installing rpm file[$(basename $rpmFile)] ...."

    doExecute rpm -qlpv $rpmFile

    #systemctl --user stop platform-interface

    doDisplay 6 "Enter root passwd ...."

    local command="systemctl --user stop platform-interface  && \
            mount -o remount,rw /usr && \
            rpm2cpio $rpmFile | cpio -idmvu && \
            cp ./usr/bin/platform-interface /usr/bin && \
            cp ./usr/bin/platform-helper-app /usr/bin && \
            systemctl restart pcoip-capability && \
            systemctl --user start platform-interface
            "

    echo "su -c \"$command\""
    su -c "$commnad"

    if [ $? -ne 0 ]; then
        doDisplay 1 "Error on install rpm file: $rpmFile"
        exit
    fi

    doDisplay 6 "Do you want enter the system now?"

    select ret in "Yes" "No"; do
        case $ret in
        Yes)
            local command="reboot root"
            su -c "$command"
            break
            ;;
        No)
            break
            doDisplay 6 "Don't forget restart the system to persist the changes"
            doDisplay 6 "Use the following command to restart the system: reboot root"
            exit
            ;;
        esac
    done

}

#**************************************************************************************************
#* Main
#**************************************************************************************************

getRunParameters $*
testParameter $*

case $operation in
ngrok)
    # in pharos

    trap trapPrepareTransferSignal INT

    countNgrok=$(ps -ef | grep -v grep | grep -c ngrok)
    if [ $countNgrok -eq 0 ]; then
        bash ./executeNgrok.sh &
    else
        doDisplay 6 "Ngrok already running ..."
    fi

    sleep 2

    ngrokHost=$(cat $ngrokLog | grep "started tunnel" | cut -d"=" -f8 | cut -d":" -f2 | sed -e "s/\/\///g")
    ngrokPort=$(cat $ngrokLog | grep "started tunnel" | cut -d"=" -f8 | cut -d":" -f3)

    doDisplay 6 "***************************************************************************************"
    doDisplay 6 " Ngrok connect string: $ngrokHost:$ngrokPort"
    doDisplay 6 " On VM device execute to transfer File"
    doDisplay 6 "   If you has the rpm file, execute the following command to transfer rpm file:"
    doDisplay 6 "       bash $(basename $0) -t <rpm file name> $ngrokHost $ngrokPort"
    doDisplay 6 "   Else, execute the following command to build and transfer rpm file:"
    doDisplay 6 "       bash $execBuild -db ubuntu-22 -wr"
    doDisplay 6 "***************************************************************************************"

    doDisplay 6 "Waiting for copy RPM file ..."
    rm -rf $tarFile*
    while true; do
        if [ -f "$tarFile.scf" ]; then
            break
        fi
        sleep 1
        echo -n "." #wait for copy file
    done
    echo " "

    extractRPMFile $tarFile
    rm -rf $tarFile*

    rpmFileVersion=$(cat $shaTransferFile | grep Version: | head -1 | tr -s " " | cut -d" " -f2)

    if [ "$rpmFileVersion" != "$version" ]; then
        doDisplay 6 "Received new script file version: $rpmFileVersion"
        doDisplay 6 "Please, restart the script to execute the new version"
        exit
    fi

    rpmFile=$(basename $(cat $shaTransferFile | grep shaRPM: | head -1 | tr -s " " | cut -d" " -f3))
    rm -rf $shaTransferFile

    doDisplay 6 "Do you want install RPM file: $rpmFile?"

    select ret in "Yes" "No"; do
        case $ret in
        Yes)
            bash $0 -i $rpmFile
            break
            ;;
        No)
            doDisplay 6 "RPM file not installed"
            exit
            ;;
        esac
    done
    ;;

transfer)
    # in vm
    prepareRPMTransfer $rpmFile
    bash $0 -c $shaTransferDir/$tarFile $ngrokHost:$ngrokPort
    rm -rf $shaTransferDir #clean up
    doDisplay 6 "Do you want enter in remote server?"
    select ret in "Yes" "No"; do
        case $ret in
        Yes)
            bash $0 -a $ngrokHost:$ngrokPort
            break
            ;;
        No) ;;
        esac
    done
    ;;
access)
    bash ./tools/sshAccess.sh $ngrokHost:$ngrokPort -u $userDest
    ;;
copy)
    bash ./tools/sshCopyFile.sh -sc $shaTransferDir/$tarFile $ngrokHost:$ngrokPort -u $userDest
    ;;
copyWindow)
    bash ./tools/sshCopyFile.sh $rpmFile $ngrokHost:$ngrokPort
    ;;
install)
    # in pharos
    if [ $(isDevicePharos) -eq 0 ]; then
        doDisplay 3 "==> Operation : $operation can not executed in this device"
        exit -1
    fi

    installRPMFile $rpmFile
    ;;
*)
    doDisplay 3 "Invalid operation: $operation"
    exit
    ;;
esac
