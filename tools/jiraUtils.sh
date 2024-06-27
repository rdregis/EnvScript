#!/bin/bash

fileJiraToken=~/.jiraToken
jiraServer=https://hp-jira.external.hp.com

getJiraTitle() {

    local jiraIssuer=$1
    jiraRet=$(curl --request GET --header 'Accept: application/json' --user $email:$token \
        --url $jiraServer/rest/api/latest/search?jql=key=$jiraIssuer 2>/dev/null)

    #echo $jiraRet
    ret=$(echo $jiraRet | grep -oe "Authentication Failure" | wc -l)
    if [ $ret -eq 1 ]; then
        doDisplay 1 "Jira authentication failure. Execute tools/installJiraToken.sh"
        exit -1
    fi

    jiraTitle=$(echo $jiraRet |
        jq -r 'paths(scalars | true) as $p  | [ ( [ $p[] | tostring ] | join(".") ), ( getpath($p) | tojson )] | join(": ")' | grep issues.0.fields.summary |
        cut -d":" -f2 | sed -e 's/\"//g' -e 's/ //')
    if [ -z "$jiraTitle" ]; then
        doDisplay 1 "Jira issue: $jiraIssuer not found on Jira Sewrver"
        exit -1
    fi
}

if [ ! -f $fileJiraToken ]; then
    doDisplay 1 "Jira token not found. Execute tools/installJiraToken.sh"
    exit -1
fi

token=$(cat $fileJiraToken | grep Token: | cut -d":" -f2)
email=$(cat $fileJiraToken | grep Email: | cut -d":" -f2)
name=$(cat $fileJiraToken | grep Name: | cut -d":" -f2)

if [ -z "$token" ] || [ -z "$email" ] || [ -z "$name" ]; then
    doDisplay 1 "Jira token not found. Execute tools/installJiraToken.sh"
    exit -1
fi
