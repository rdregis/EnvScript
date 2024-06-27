#!/bin/bash

version=1.1.0

md5TransferDir=~/.transferRPMFile
md5TransferFile=transferFile.md5
tarFile=transferFile.tar.gz
userDest=pharos
userOrigin= #rregis
userLocal=rregis
dirDest=/home/$userLocal
curlNgrok="https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip"
ngrokDir=./ngrok
ngrokLog=$(mktemp /tmp/ngrok.log.XXXXXX)
tmpScript=$(mktemp /tmp/transferRPMFile.sh.XXXXXX)
tmpRPMFile=$(mktemp /tmp/transferRPMFile.rpm.XXXXXX)

rpmFile=
ngrokHost=
ngrokPort=

showHelp() {
    # `cat << EOF` This means that cat should stop reading when EOF is detected
    cat <<EOF

Copy and instal rpm files: $version
Usage: $0 [ -h ] | [ ] | [ -t <ngok host> <ngrok port> <rpm file name> ] | [ -i <rpm file name> ]
Usage: $0 [ -h ] | [ -t <rpm file name> ] | [ -c <ngok host> <ngrok port> ] | [ -i <rpm file name>]

-h,  -help,        	--help          	Display help
-t  -transfer	       	--transfer   		Execute ngrok application to transfer rpm file
-c  -copy	       	--copy    		Copy rpm file from remote device
-i  -install	       	--install    		Install rpm file on destination device

<rpm file name>:          		File name of rpm to be transfered and copied
<ngrok host>:          		    Host name of ngrok server
<port>:	  		                Port of ngrok server

	
Pre-requesits: 
    - ngrok application must be installed on the origin system
    - Generate a token on https://dashboard.ngrok.com/auth/your-authtoken
        - Execute the following command: ngrok authtoken <token>
  
Notes:
    - To transfer: (executed in origin system)
        - Build the rpm file before execute this script
        - This script will execute ngrok application to transfer rpm file and will wait for copy file
    - To copy (executed in destination system)
        - The transfer script must be been executed in origin system
    - To install (executed in destination system)
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
            operation=transfer
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
            shift
            rpmFile=$1
            break
            ;;
        -c | --copy)
            operation=copy
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
            shift
            rpmFile=$1
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

    transfer | copy)
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

    copy)
        if [ -f "$rpmFile" ]; then
            return 2
        fi
        doDisplay 3 "==> Invalid copy file parameter: $rpmFile"
        ;;

    install)
        if [ ! -z "$ngrokHost" ] && [ ! -z "$ngrokPort" ]; then
            count=$(nc -z -v -w5 $ngrokHost $ngrokPort 2>&1 | grep -c succeeded)
            if [ $count -eq 1 ]; then
                return 3
            fi
        fi
        rpmFile=""
        doDisplay 3 "==> Invalid ngrok host or port parameter: $ngrokHost:$ngrokPort"
        doDisplay 3 "$(nc -z -v -w5 $ngrokHost $ngrokPort 2>&1)"
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

    execKill "/tmp/ngrok.log" 1
    execKill ngrok 5
}

executeNgrok() {

    doDisplay 6 "Executing ngrok ...."

    if [ $(isDevicePharos) -eq 1 ]; then
        ./ngrok/ngrok tcp 22 --log=stdout >$ngrokLog 2>&1 &
    else
        ngrok tcp 22 --log=stdout --region us-cal-1 >$ngrokLog 2>&1 &
    fi

    gnome-terminal -q -e "tail -f $ngrokLog" >/dev/null 2>&1 &

    sleep 3

}

trapPrepareTransferSignal() {
    doDisplay 6 "Capturing Ctrl-c signal ..."
    killAll

    sleep 1
    exit -1
}

prepareRPMTransfer() {
    local rpmFile=$1

    if [ ! -d "$md5TransferDir" ]; then
        mkdir -p $md5TransferDir
    fi

    cp $0 $md5TransferDir/$(basename $0)
    cp $rpmFile $md5TransferDir/$rpmFile

    echo "Version: $version" >$md5TransferDir/$md5TransferFile
    echo "Script: $(
        cd -- "$(dirname "$0")" >/dev/null 2>&1
        pwd -P
    )/$(basename $0)" >>$md5TransferDir/$md5TransferFile

    local md5Value=$(md5sum $md5TransferDir/$rpmFile)
    echo "md5RPM: $md5Value" >>$md5TransferDir/$md5TransferFile

    local md5Value=$(md5sum $md5TransferDir/$(basename $0))
    echo "ms5Script: $md5Value" >>$md5TransferDir/$md5TransferFile

    rm -rf $md5TransferDir/$tarFile

    tar -czvf $md5TransferDir/$tarFile -C $md5TransferDir . 2>/dev/null
    #tar -tvf $md5TransferDir/$tarFile
}

prepareRPMTransferOld() {

    trap trapPrepareTransferSignal INT
    installPackage ngrok

    killAll
    executeNgrok &
    sleep 2

    if [ ! -d "$md5TransferDir" ]; then
        mkdir -p $md5TransferDir
    fi

    echo "Version: $version" >$md5TransferFile
    echo "Script: $(
        cd -- "$(dirname "$0")" >/dev/null 2>&1
        pwd -P
    )/$(basename $0)" >>$md5TransferFile

    local md5Value=$(md5sum $(pwd)/$rpmFile)
    echo "RPM: $md5Value" >>$md5TransferFile

    checkMd5 $rpmFile $md5Value

    ngrokHost=$(cat $ngrokLog | grep "started tunnel" | cut -d"=" -f8 | cut -d":" -f2 | sed -e "s/\/\///g")
    ngrokPort=$(cat $ngrokLog | grep "started tunnel" | cut -d"=" -f8 | cut -d":" -f3)

    doDisplay 6 "***************************************************************************************"
    doDisplay 6 " On remote device exeucte the following commands to transfer File: $(pwd)/$rpmFile"
    doDisplay 6 " bash /home/pharos/transferRPMFile.sh $ngrokHost $ngrokPort"
    doDisplay 6 "***************************************************************************************"

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
    doExecute "scp -P $port $file $user@$host:$destFile" # >/dev/null #2>&1

    if [ $? -ne 0 ]; then
        doDisplay 1 "Error on scp copying file: $file"
        exit
    fi
}
checkMd5() {
    local file=$1
    local md5Value=$2

    doDisplay 6 "Checking md5sum file[$(basename $file)] ...."

    echo "$md5Value  $file" | md5sum -c - >/dev/null

    if [ $? -ne 0 ]; then
        doDisplay 1 "Error on md5sum file: $file"
        exit
    fi
}

tranferRPMFile() {
    doDisplay 6 "Getting rpm file to Pharos device ..."

    local localFile=$(echo $dirDest/$(basename $md5TransferFile))
    copyFile $md5TransferFile "$userOrigin" $ngrokHost $ngrokPort $localFile

    local fileScript=$(cat $localFile | grep Script: | cut -d":" -f2)
    # echo xxxx $fileScript

    remoteVersion=$(cat $localFile | grep Version: | cut -d":" -f2 | sed -e "s/ //g")
    # echo xxxxx $version $remoteVersion "$version" "!=" "$remoteVersion"
    if [ "$version" != "$remoteVersion" ]; then
        echo xzxzxzxzzxxzx
        local fileScript=$(cat $localFile | grep Script: | cut -d":" -f2)
        echo yyy $fileScript
        copyFile $fileScript "$userOrigin" $ngrokHost $ngrokPort $tmpScript
        mv $tmpScript $fileScript
        exit
    fi

    local rpmFile=$(cat $localFile | grep RPM: | head -1 | cut -d" " -f4)
    local md5Value=$(cat $localFile | grep RPM: | head -1 | cut -d" " -f2,3,4)
    # echo $rpmFile $md5Value
    copyFile $rpmFile "$userOrigin" $ngrokHost $ngrokPort $tmpRPMFile

    checkMd5 $tmpRPMFile $md5Value

}
installRPMFile() {
    local rpmFile=$1

    doDisplay 6 "Installing rpm file[$(basename $rpmFile)] ...."

    systemctl --user stop platform-interface

    #su -c "rpm2cpio $rmpFile| cpio -idmv"
    cp ./usr/bin/platform-interface /usr/bin
    cp ./usr/bin/platform-helper-app /usr/bin

    systemctl restart pcoip-capability
    reboot root

    if [ $? -ne 0 ]; then
        doDisplay 1 "Error on install rpm file: $rpmFile"
        exit
    fi
}

installNgrokOnPharos() {

    if [ ! -d "$ngrokDir" ]; then
        mkdir $ngrokDir
    fi

    cd $ngrokDir
    if [ ! -f "ngrok" ]; then
        doDisplay 6 "==> Instalation ngrok application"
        curl $curlNgrok --output ngrok.zip
        unzip ngrok.zip
        rm ngrok.zip
        read -p "Enter your ngrok token: " ngrokToken
        ngrok authtoken $ngrokToken
    fi

    doDisplay 6 "==> Updating ngrok application"
    ./ngrok update

    cd ..

}
#**************************************************************************************************
#* Main
#**************************************************************************************************

getRunParameters $*
testParameter $*

case $operation in
ngrok)
    # in pharos
    installNgrokOnPharos
    trap trapPrepareTransferSignal INT
    killAll
    executeNgrok &
    sleep 2

    ngrokHost=$(cat $ngrokLog | grep "started tunnel" | cut -d"=" -f8 | cut -d":" -f2 | sed -e "s/\/\///g")
    ngrokPort=$(cat $ngrokLog | grep "started tunnel" | cut -d"=" -f8 | cut -d":" -f3)
    doDisplay 6 "***************************************************************************************"
    doDisplay 6 " Ngrok connect string: $ngrokHost:$ngrokPort"
    doDisplay 6 " On VM device execute to transfer File"
    doDisplay 6 "   If you has the rpm file, execute the following command to transfer rpm file:"
    doDisplay 6 "       bash $(basename $0) -t $ngrokHost $ngrokPort <rpm file name>"
    doDisplay 6 "   Else, execute the following command to build and transfer rpm file:"
    doDisplay 6 "       bash $execBuild -db ubuntu-22 -wr"
    doDisplay 6 "***************************************************************************************"

    doDisplay 6 "Do you want install RPM file?"

    select ret in "Yes" "No"; do
        case $ret in
        Yes)
            rm -rf $tarFile
            while true; do
                if [ -f "$tarFile" ]; then
                    break
                fi
                sleep
                echo -n "." #wait for copy file
            done
            break
            ;;
        No)
            read -p "Press enter to finalize when copy is done..." #wait for copy file
            break
            ;;
        esac
    done

    read -p "Press enter to finalize when copy is done..." #wait for copy file
    killAll
    ;;
transfer)
    # in vm
    prepareRPMTransfer $rpmFile
    bash $0 -c $ngrokHost:$ngrokPort $md5TransferDir/$tarFile
    ;;
copy)
    copyFile $rpmFile $userDest $ngrokHost $ngrokPort
    ;;
install)
    # in pharos
    doDisplay 3 "Operation not implemented: $operation"
    ;;
*)
    doDisplay 3 "Invalid operation: $operation"
    exit
    ;;
esac

exit
