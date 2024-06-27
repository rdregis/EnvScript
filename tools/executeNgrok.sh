#!/bin/bash

version=1.1.0
curlNgrok="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz"
ngrokDir=~/ngrok.dir
ngrokLog=$ngrokDir/ngrok.log

doDisplay() {
    local color=$1
    shift
    local msg=$*
    echo "$(tput setaf $color)$msg $(tput sgr0)"
}

isDevicePharos() {
    local count=$(hostnamectl | egrep -e "Wind River Linux" -e "Chassis: laptop" | wc -l)

    if [ $count -gt 0 ]; then
        echo 1
        return
    fi

    echo 0
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

installNgrokOnPharos() {

    if [ ! -d "$ngrokDir" ]; then
        mkdir $ngrokDir
    fi

    cd $ngrokDir
    if [ ! -f "ngrok" ]; then
        doDisplay 6 "==> Instalation ngrok application"
        wget $curlNgrok -O ngrok.tar
        tar xvzf ngrok.tar
        rm ngrok.tar

        ./ngrok config upgrade
        read -p "Enter your ngrok token(https://ngrok.com/): " ngrokToken
        ./ngrok authtoken $ngrokToken
    fi

    doDisplay 6 "==> Updating ngrok application"
    ./ngrok update

    cd ..

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

if [ $(isDevicePharos) -eq 0 ]; then
    doDisplay 3 "==> Operation : $operation can not executed in this device"
    exit -1
fi

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
doDisplay 6 "       bash $(basename $0) -t <rpm file name> $ngrokHost $ngrokPort "
doDisplay 6 "   Else, execute the following command to build and transfer rpm file:"
doDisplay 6 "       bash $execBuild -db ubuntu-22 -wr"
doDisplay 6 "***************************************************************************************"

read -p "Press enter to finalize when copy is done..." #wait for copy file
#killAll
