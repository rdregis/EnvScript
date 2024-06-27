#!/bin/bash
source $(dirname $0)/jiraUtils.sh

if [ $# -lt 2 ]; then
    echo "==> Invalid Parameter. Use $0 <release branch name> <Jira issuer> [ clear | reset | finalize | <file commits> | <cherry commit id> ]"
    exit
fi

branchRel=$1
jiraIssuer=$2
scriptOptions=$3

branchMaster=main
fileCommits=./cherryPick.commit
cherryFileDate=./cherryPick.date
cherryFileInsert=./cherryPick.insert
cherryFileError=$(mktemp /tmp/cherryPick.error.XXXXXX)
cherryFilePull=$(mktemp /tmp/cherryPick.pull.XXXXXX)

doDisplay() {
    local color=$1

    shift
    local msg=$*
    echo "$(tput setaf $color)$msg $(tput sgr0)"

    #read -p "Press enter to continue"
}

commitPosition() {
    local commitId=$1
    local branch=$2

    posCommit=$(git log $branch | grep commit | grep -n $commitId | cut -d":" -f1)

    echo $posCommit
}

convertToObjectDate() {

    local fmtDate=$1
    local timeZone=$2

    local timeZoneShort=${timeZone:0:3}

    local format="%a %b %d %T %Y" # %z"

    local objectDate=$(date -d "$fmtDate" "+$format")
    local dateNew=$(date --utc --date="$objectDate + $timeZoneShort hours")

    echo $dateNew
}

verifyCherryDate() {

    local commitId=$1
    local commitObjDate=$2

    while read lineCherry; do

        lineDate=$(echo $lineCherry | cut -d" " -f1-5)
        lineDateTZ=$(echo $lineCherry | cut -d" " -f6)

        lineObjDate=$(convertToObjectDate "$lineDate" "$lineDateTZ")

        if [[ $(date --date="$lineObjDate" +"%s") > $(date --date="$commitObjDate" +"%s") ]]; then
            echo Error >$cherryFileError
            echo "***********************************************************" >>$cherryFileError
            echo "Commit $commitId was rejected because last cherry-pick is greater then commit date" >>$cherryFileError
            echo "Last cherry-pick date: $(date -d "$lineObjDate")" >>$cherryFileError
            echo "Commit date: $(date -d "$commitObjDate")" >>$cherryFileError
            echo "***********************************************************" >>$cherryFileError
            echo 0
            return
        fi
    done <$cherryFileDate

    echo 1
}

prepareBranch() {

    if [ -f $cherryFileDate ]; then
        doDisplay 6 "==> Cherry pick process will be use the branch [$branchCherry]"
        return
    fi

    doDisplay 6 "==> Switch to branch [main]"
    git checkout main >/dev/null
    git pull >/dev/null
    git fetch --all >/dev/null

    local countRel=$(git branch --all | grep "$branchRel" | wc -l)
    if [ $countRel -eq 0 ]; then
        doDisplay 6 "==> Branch $branchRel no exist"
        exit
    fi

    local countRel=$(git branch --all | grep -w " $branchRel" | wc -l)
    if [ $countRel -eq 0 ]; then
        doDisplay 6 "==> Branch $branchRel no checkouted"
    fi

    doDisplay 6 "==> Switch to branch [$branchRel]"

    git checkout $branchRel >/dev/null
    git pull >/dev/null
    git status >/dev/null

    doDisplay 6 "==> Cherry pick branch $branchCherry "
    countCherry=$(git branch --all | grep -w "$branchCherry" | wc -l)

    if [ $countCherry -gt 0 ]; then
        doDisplay 6 "==> Switch to branch [$branchCherry]"
        git checkout $branchCherry
        return
    fi

    countRel=$(echo $branchRel | grep -i "release" | wc -l)
    if [ $countRel -eq 1 ]; then
        doDisplay 6 "==> Creating Cherry pick branch $branchCherry "
        git checkout -b $branchCherry
        touch $cherryFileDate
        return
    fi

    doDisplay 6 "==> Branch $branchRel is not a release branch"
    doDisplay 6 "==> Do you wish continue?"
    select ret in "Yes" "No"; do
        case $ret in
        Yes)
            doDisplay 6 "==> Creating Cherry pick branch $branchCherry "
            git checkout -b $branchCherry
            touch $cherryFileDate
            break
            ;;
        No)
            exit
            ;;
        esac
    done

}

createFileDesc() {
    echo "- ### Cherry pick to: $branchRel" >>$cherryFilePull

    cat $cherryFileInsert | while read lineCherry; do
        local title=$(git show $lineCherry | tail -n +5 | head -1 | awk '{print substr($0, 5)}')
        local subject=$(git show $lineCherry | tail -n +7 | head -1 | awk '{print substr($0, 7)}')
        echo "#### $title" >>$cherryFilePull
        echo "> Commit: $lineCherry" >>$cherryFilePull
        local jiraCommit=$(echo $subject | cut -d" " -f1)
        while read line; do
            echo "      - $line" >>$cherryFilePull
        done < <(git log $branchMaster | grep $jiraCommit | grep -vw "Merge" | egrep -v "[A-Za-z0-9]+\s+\(#[0-9]+\)" | sed -e s/$jiraCommit//)
        echo " " >>$cherryFilePull
    done

    #cat $cherryFilePull

}

clearBranch() {
    git reset --hard
    git checkout main

    if [ ! -z $(git branch --all | grep -w " $branchCherry") ]; then
        doDisplay 6 "==> Deleting branch [$branchCherry]"
        git branch -D $branchCherry
    fi

    rm -f $cherryFileDate
    rm -f $cherryFileInsert
}

finalizeCherry() {
    doDisplay 6 "==> Finalizing Cherry pick branch $branchCherry "

    cat $cherryFileInsert | while read lineCherry; do
        doDisplay 5 Commit: $lineCherry [$(git show $lineCherry | grep Date)] $(git show $lineCherry | grep Author)
        # doDisplay 5 $(git show $lineCherry | grep Date)
        # doDisplay 5 $(git show $lineCherry | grep Author)
        # echo

    done
    git branch | grep "\*"
    doDisplay 6 "Do you agree?"
    select ret in "Yes" "No"; do
        case $ret in
        Yes)
            break
            ;;
        No)
            exit
            ;;
        esac
    done

    doDisplay 6 "==> Executing git push for branch $branchCherry "

    git push --set-upstream origin $branchCherry

    countPush=$(git status | grep -e "Your branch is up to date with" -e "Everything up-to-date" | wc -l)
    if [ $countPush -eq 0 ]; then
        doDisplay 1 "==> Pushing Cherry pick ERROR on branch $branchCherry "
        exit
    fi

    doDisplay 6 "Do you create the pull request?"
    select ret in "Yes" "No"; do
        case $ret in
        Yes)
            bash $0 $branchRel $jiraIssuer pullRequest
            break
            ;;
        No)
            break
            ;;
        esac
    done

    clearBranch

}

verifyCommit() {

    local commitId=$*

    #countCommit=$(git log | grep ^commit | grep $commitId | wc -l)
    local countCommit=$(git show $commitId 2>/dev/null | wc -l)
    if [ $countCommit -eq 0 ]; then
        doDisplay 1 "==> Cherry pick of commit: '$commitId' is not found"
        exit
    fi

    countCommit=$(git log $branchMaster | grep $commitId 2>/dev/null | wc -l)
    if [ $countCommit -eq 0 ]; then
        doDisplay 1 "==> Cherry pick of commit: '$commitId' is not found in branch: $branchMaster"
        exit
    fi

}

insertCherryCommit() {

    local commitFile=$1

    doDisplay 6 "Inserting commits from file: $commitFile"

    index=0
    while read lineCommit; do

        retVer=$(verifyCommit $lineCommit)
        if [ ! -z "$retVer" ]; then
            echo $retVer
            exit
        fi
        commitDate=$(git show $lineCommit | grep Date: | cut -d":" -f2-4 | cut -d" " -f1-8)

        #echo $index $lineCommit $commitDate
        listCommit[index]="$commitDate $lineCommit"
        ((index++))
    done <$commitFile

    tmpfile=$(mktemp /tmp/abc-script.XXXXXX)

    for element in "${listCommit[@]}"; do
        echo $element
    done | sort -n -t' ' -k5 -k2M -k3,4 >$tmpfile

    index=0
    while read element; do
        listCommitSorted[index]="$element"
        ((index++))
    done <$tmpfile

    doDisplay 6 "Do you agree with this commit date order?"
    for element in "${listCommitSorted[@]}"; do
        commitAuthor=$(git show $(echo $element | cut -d " " -f 6) | grep Author)
        echo "$element $commitAuthor"
    done

    select ret in "Yes" "No"; do
        case $ret in
        Yes)
            bash $0 $branchRel $jiraIssuer reset
            for element in "${listCommitSorted[@]}"; do
                commit=$(echo $element | cut -d " " -f 6)
                doDisplay 6 "==> Cherry pick commit: $commit"
                bash $0 $branchRel $jiraIssuer $commit
                if [ $? -ne 0 ]; then
                    doDisplay 1 "==> Cherry pick of commit: $commitId was not inserted"
                    exit
                fi
            done
            bash $0 $branchRel $jiraIssuer finalize
            break
            ;;
        No)
            doDisplay 6 Please, recreate file: $commitFile
            exit
            ;;
        esac
    done

}

getCommits() {

    local fileCommits=$1
    doDisplay 6 "==> Getting commits from branch $branchCherry "

    >$fileCommits
    local isFinish=0
    while [ $isFinish == 0 ]; do
        doDisplay 6 "Enter the Commit Id or empty to finalize: "
        read readCommit
        if [ -z "$readCommit" ]; then # empty
            bash $0 $branchRel $jiraIssuer $fileCommits
            mv -f $fileCommits $fileCommits.bkp
            isFinish=1
            continue
        fi
        local countCommit=$(cat $fileCommits | grep -c "$readCommit")
        if [ $countCommit -gt 0 ]; then
            doDisplay 1 "==> Cherry pick of commit: '$readCommit' already exists"
            continue
        fi
        local retVer=$(verifyCommit $readCommit)
        if [ ! -z "$retVer" ]; then
            echo $retVer
            continue
        fi
        echo $readCommit >>$fileCommits
    done
}

#************************************************************************
# Main
#************************************************************************

getJiraTitle $jiraIssuer
if [ -z "$jiraTitle" ]; then
    doDisplay 1 "Jira issue: $jiraIssuer not found on Jira"
    exit -1
fi

countName=$(echo $jiraTitle | grep -ci "cherrypick")
if [ $countName -eq 0 ]; then
    doDisplay 1 "Jira issue: $jiraIssuer is not a cherrypick"
    doDisplay 1 "Include '[CherryPick]' on name of the Jira issue: $jiraIssuer"
    exit -1
fi

branchCherry=cherrypick/$jiraIssuer/$(users | cut -d"\\" -f 2)/$(echo $branchRel | tr "/" "_")

repoName=$(basename -s .git "$(git config --get remote.origin.url)")
doDisplay 2 On repository [$repoName] executing[$version]: $0 $*

if [ ! -d ".git" ]; then
    doDisplay 1 "Execute this script on repository [$repoName] home dir"
    exit -4
fi

case $scriptOptions in
"")
    # Ask for commits
    prepareBranch
    getCommits $fileCommits
    # next step: bash $0 $branchRel $jiraIssuer $fileCommits
    exit
    ;;
clear)
    clearBranch
    exit
    ;;
reset)
    clearBranch
    prepareBranch
    exit
    ;;
finalize)
    prepareBranch
    if [ ! -f $cherryFileInsert ]; then
        doDisplay 1 "==> Cherry pick is empty. Use $0 <release branch name> <Jira issuer> <cherry commit id>"
        exit
    fi
    doDisplay 6 "Do you wish finalize cherry-pick?"
    select ret in "Yes" "No"; do
        case $ret in
        Yes)
            finalizeCherry
            exit
            ;;
        No)
            exit
            ;;
        esac
    done
    exit
    ;;
pullRequest)
    prepareBranch
    createFileDesc
    bash $(dirname $0)/createPR.sh $jiraIssuer $cherryFilePull
    exit
    ;;

*)
    commitId=$scriptOptions
    if [ -f $commitId ]; then
        insertCherryCommit $commitId
        # Processing commit id
        exit

    fi
    # Processing commit id
    ;;
esac

# for entering commit id

prepareBranch

verifyCommit $commitId

if [ -f $cherryFileInsert ]; then
    countCommit=$(cat $cherryFileInsert | grep -c $commitId)
    if [ $countCommit -gt 0 ]; then
        doDisplay 1 "==> Cherry pick of commit: $commitId already exists"
        exit
    fi
fi

commitDate=$(git show $commitId | grep Date: | cut -d":" -f2-4 | cut -d" " -f1-8)
commitDateTZ=$(git show $commitId | grep Date: | cut -d":" -f2-4 | cut -d" " -f9)
commitObjDate=$(convertToObjectDate "$commitDate" "$commitDateTZ")

verifyDate=1

if [ -f $cherryFileDate ]; then
    verifyDate=$(verifyCherryDate $commitId "$commitObjDate")
fi

if [ $verifyDate -eq 0 ]; then
    doDisplay 1 "$(cat $cherryFileError)"
    doDisplay 6 "Do you wish reset cherry-pick?"
    select ret in "Yes" "No"; do
        case $ret in
        Yes)
            clearBranch
            exit 1
            ;;
        No)
            exit 1
            ;;
        esac
    done

fi

echo $(git show $commitId | grep Date: | cut -d":" -f2-5) >$cherryFileDate
echo $commitId >>$cherryFileInsert

#echo xxxx $(commitPosition $commitId)

doDisplay 6 "==> Allowed Cherry pick commit: [$commitObjDate] $commitId $(git show $commitId | grep Author)"
git cherry-pick $commitId
exit 0
