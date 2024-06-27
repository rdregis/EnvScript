#!/bin/bash

fileJiraToken=~/.jiraToken
doDisplay() {
    local color=$1

    shift
    local msg=$*
    echo "$(tput setaf $color)$msg $(tput sgr0)"

    #read -p "Press enter to continue"
}
saveToken() {
    local name=$1
    local email=$2
    local token=$3

    doDisplay 6 "Are you sure you want to save the token?"

    select ret in "Yes" "No"; do
        case $ret in
        Yes)
            break
            ;;
        No)
            exit -1
            ;;
        esac
    done

    echo "server:https://hp-jira.external.hp.com" >$fileJiraToken
    echo "Date:$(date)" >>$fileJiraToken
    echo "Name:$name" >>$fileJiraToken
    echo "Email:$email" >>$fileJiraToken
    echo "Token:$token" >>$fileJiraToken
    doDisplay 2 "Token saved successfully"
}
testToken() {
    local email=$1
    local token=$2

    local ret=$(curl -s -u $email:$token https://hp-jira.external.hp.com/rest/api/2/myself | grep -oe "Authentication Failure" | wc -l)
    if [ $ret -eq 1 ]; then
        #doDisplay 1 "Invalid jira email/token"
        return 0
    fi
    return 1
}

ok=0
while [ $ok -eq 0 ]; do
    doDisplay 6 "Install Jira token."
    doDisplay 6 "Enter your name:"
    read name
    doDisplay 6 "Enter your e-mail:"
    read email
    countMail=$(echo $email | grep -oe "[a-zA-Z0-9._]\+@[a-zA-Z]\+.[a-zA-Z]\+" | wc -l)
    if [ $countMail -eq 0 ]; then
        doDisplay 1 "Invalid e-mail"
        continue
    fi
    doDisplay 6 "Enter jira token: Get your token from https://https://hp-jira.external.hp.com/plugins/servlet/de.resolution.apitokenauth/admin"
    read token
    doDisplay 2 Name:$name
    doDisplay 2 Email:$email
    doDisplay 2 Token:$token
    doDisplay 6 "Are you agree?"
    select ret in "Yes" "No"; do
        case $ret in
        Yes)
            if testToken $email $token; then
                doDisplay 1 "Invalid jira email/token"
                break
            fi
            saveToken "$name" $email $token
            ok=1
            break
            ;;

        No)
            break
            ;;
        esac
    done
done
