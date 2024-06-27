#!/bin/bash

dockerContainer=trust-agent
trustDir=../trust-agent
regURI="https://register.dogfood-dev.aws.hydra.teradici.com:32443"
scriptPY=$trustDir/examples/py-ta-client
fileConf=".devBuild.conf"

dockerMessage=$(mktemp /tmp/docker.message.XXXXXX)
platformMessage=$(mktemp /tmp/docker.message.XXXXXX)
#piMessage=./PI.message

dockerRun=0

doDisplay() {
    local color=$1

    shift
    local msg=$*
    echo "$(tput setaf $color)$msg $(tput sgr0)"

    #read -p "Press enter to continue"
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
            sudo kill -2 $pid
            sleep $wait
            existTask2=$(ps -ef | grep -v grep | grep -c $pid)
            if [ $existTask2 -ne 0 ]; then
                kill -9 $pid
                sleep 1
            fi
        fi
    done

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

stopDocker() {
    local container=$1

    doDisplay 6 "Stopping docker ...: $container"
    docker stop -t 10 $(docker ps | grep $container | cut -d" " -f1)
    dockerRun=0
}

wantStopDocker() {
    local container=$1

    local countDocker=$(docker ps | grep $container | wc -l)

    if [ $countDocker == 1 ]; then
        dockerRun=1
        doDisplay 6 "The docker: $container is running"
        doDisplay 6 "Do you wish restart docker:"
        select ret in "Yes" "No"; do
            case $ret in
            Yes)
                stopDocker $container
                break
                ;;
            No)
                break

                ;;
            esac
        done
    fi
}

executeAgent() {

    doDisplay 6 "Executing Trust Agent ...."
    pushd $trustDir 2>/dev/null

    #make run >/dev/null >>$dockerMessage &
    docker run --rm -p 3332:3332 -p 3333:3333 -e ENDPOINT_ID="docker-$($users)-$(date '+%Y-%m-%dT%H-%M-%S')" \
        -e REGISTRATION_URI=$regURI trust-agent:latest >/dev/null >>$dockerMessage &

    gnome-terminal -q -e "tail -f $dockerMessage" >/dev/null 2>&1 &

    dockerRun=1
    sleep 5
    popd 2>/dev/null
}

executePlatform() {

    doDisplay 6 "Executing Platform Interface...."

    local appName=
    for file in $(find -L . -type f -perm -a=x | grep -e "platform_interface" | grep "app/"); do
        isbldScript=$(echo $file | grep -c "buildFromScript")
        if [[ $isbldScript -eq 0 ]]; then
            fileSel=$(echo "[___]$file")
        else
            fileSel=$(echo "[bld]$file")
            buildDir=$(echo $file | cut -d '/' -f1,2,3)
            if [ -f $buildDir/$fileConf ]; then
                fileSel=$(echo "["$(cat $buildDir/$fileConf | cut -d " " -f1)"]"$file)
            fi
        fi
        appName=$(echo $appName $fileSel)
    done

    echo x $appName
    echo y $appName | sort
    doDisplay 6 "What the platform_interface app do you wish?"
    while [ -z $retApp ]; do
        select retApp in "Debug" "Other" $(echo $appName | xargs -n1 | sort | xargs); do
            case $retApp in
            Debug)
                doDisplay 3 "Execute platform-interface on vs code as debug mode"
                read -p "Press enter to continue"
                return
                ;;
            $appName)
                break
                ;;
            Other)
                echo "Enter the platform interface app name: "
                read appRead
                if [ -z $appRead ]; then
                    doDisplay 6 "Invalid app name"
                    exit
                fi
                if [ ! -f $appRead ]; then
                    doDisplay 6 "Platform Interface app: $appRead not found"
                    exit
                fi
                retApp="[]"$appRead
                break
                ;;

            *)
                break
                ;;
            esac
        done

        if [ -z $retApp ]; then
            doDisplay 6 "Invalid platform_interface app"

        fi
    done

    executePlatformApp=$(echo $retApp | cut -d"]" -f2)
    doDisplay 6 "Executing platform interface app: $executePlatformApp"
    execKill platform-interface 1
    doExecute $executePlatformApp -p . --TA2 &

    doDisplay 3 "Usage Platform Helper app: $(ls -la /usr/bin/platform-helper-app)"

    execCount=$(ps -ef | grep -v grep | grep -c "platform-interface")
    if [ $execCount -eq 0 ]; then
        doDisplay 1 "*************************************************************"
        doDisplay 1 "* Error on execute platform interface app: $executePlatformApp"
        doDisplay 1 "*************************************************************"
        exit -1
    fi
    #gnome-terminal -e "tail -f $piMessage" >/dev/null 2>&1 &

    sleep 5

}
killAll() {
    doDisplay 6 "Killing all process ..."
    stopDocker $dockerContainer
    execKill "/tmp/docker.message" 1
    execKill platform-interface 5
}
trapIntSignal() {
    doDisplay 6 "Capturing Ctrl-c signal ..."
    killAll

    sleep 1
    exit -1
}
enterModule() {

    local fileOper="trust-agent-ipc/ta_ipc_schema/api/ta_ipc_schema.h"
    START="enum class IpcKeyType"
    END="};"

    #echo $dataFile

    local moduleList
    while read line; do
        if [ -z "$line" ]; then
            continue
        fi
        if [ $(echo $line | grep -c "//") -gt 0 ]; then
            continue
        fi
        if [ $(echo $line | grep -c ",") -eq 0 ]; then
            continue
        fi
        module=$(echo $line | sed -e 's/,//g')
        #operation=$(cat $fileOper | grep "constexpr auto" | grep $enumOper | cut -d"=" -f2 | sed -e 's/ //g')

        moduleList=$(echo $moduleList $module)
    done < <(cat $fileOper | sed -n "/$START/,/$END/p" | tail -n +3)

    doDisplay 6 "Enter the module:"
    select ret in $(echo $moduleList | tr ' ' '\n' | sort | tr '\n' ' ') "Other"; do
        case $ret in
        Other)
            exit
            ;;
        *)
            operation=$(cat $fileOper | grep -w "constexpr auto $ret" | cut -d"=" -f2 | sed -e 's/ //g' -e 's/;//g' -e 's/\"//g')
            enterOperation $operation
            break
            ;;
        esac
    done

}
enterOperation() {

    local module=$1
    doDisplay 6 "Enter the operation:"
    select ret in "Get" "Update" "Subscribe"; do
        case $ret in
        Get)
            doExecute $scriptPY/get.py -p /properties/reported/$module
            break
            ;;
        Update)
            doExecute $scriptPY/update.py #-p /properties/reported/$module
            exit
            ;;
        Subscribe)
            doExecute $scriptPY/subscribe.py #-p /properties/reported/$module
            exit
            ;;
        esac
    done
}

#**************************************************************************************************
#* Main
#**************************************************************************************************

trap trapIntSignal INT

wantStopDocker $dockerContainer

if [ $dockerRun == 0 ]; then
    executeAgent &

fi
sleep 5
#read -p "Press enter to continue"

executePlatform

while [ "$retInfo" != "No" ]; do
    enterModule
    doDisplay 6 "Do you wish new information:"
    select retInfo in "Yes" "No"; do
        case $retInfo in
        Yes)
            break
            ;;
        No)
            break
            ;;
        esac

    done
done

killAll
