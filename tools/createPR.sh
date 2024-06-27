#!/bin/bash

# Path: tools/createPR.sh
# Compare this snippet from testPY.sh:
# #!/bin/bash
#

if [ $# -lt 1 ]; then
    echo "==> Invalid Parameter. Use $0  <Jira issuer> [<description file>]"
    exit
fi

jiraIssuer=$1
inpDescFile=$2

branchMaster=main
fileJiraToken=~/.jiraToken
filePull=$(mktemp /tmp/filePull.pull.XXXXXX)

if [ -z "$inpDescFile" ]; then
    fileDesc=$(mktemp /tmp/filePull.desc.XXXXXX)
else
    if [ ! -f "$inpDescFile" ]; then
        echo "==> Description file: [$inpDescFile] not exist. Use $0  <Jira issuer> [<description file>]"
        exit
    fi
    fileDesc=$inpDescFile
fi

doDisplay() {
    local color=$1

    shift
    local msg=$*
    echo "$(tput setaf $color)$msg $(tput sgr0)"

    #read -p "Press enter to continue"
}

preparePullRequest() {

    local jiraIssuer=$1
    local title=$2

    echo "## Contributing" >>$filePull
    echo "When contributing to this repository, please first discuss the change you wish to make via issue," >>$filePull
    echo "Please review the guidelines for contributing to this repository." >>$filePull
    echo "## Related User Stories" >>$filePull
    echo "* [$title](https://hp-jira.external.hp.com/browse/$jiraIssuer)" >>$filePull

    echo "## Type of change" >>$filePull

    echo "Please delete options that are not relevant." >>$filePull

    echo "- [ ] New feature (non-breaking change which adds functionality)" >>$filePull
    echo "- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)" >>$filePull
    echo "- [ ] Unit Tests" >>$filePull
    echo "- [ ] Documentation" >>$filePull
    echo "- [X] Release" >>$filePull

    echo "## Reason:" >>$filePull
    chooseReason "$title"
    echo "#### $reason" >>$filePull

    chooseDescripion "$title"
    echo "## Description:" >>$filePull
    cat $fileDesc >>$filePull

    echo "## Collaborator:" >>$filePull
    echo "Date:" $(date) >>$filePull
    echo "Name:" $name >>$filePull
    echo "Email:" $email >>$filePull

    echo "## Checklist:" >>$filePull
    echo "Please delete options that are not relevant." >>$filePull
    echo "- [X] The commits include only changes related to the goal of this PR." >>$filePull
    echo "- [ ] I have commented on my code, particularly in hard-to-understand areas" >>$filePull
    echo "- [ ] I have made corresponding changes to the documentation" >>$filePull
    echo "- [ ] My changes generate no new warnings" >>$filePull
    echo "- [ ] I have added tests that prove my fix is effective or that my feature works" >>$filePull
    echo "- [ ] New and existing unit tests pass locally with my changes" >>$filePull
    echo "- [ ] Have run linter and fixed all linter errors and warnings" >>$filePull
    echo "## How Has This Been Tested?" >>$filePull
    echo "Not necessary. Origin cade was tested" >>$filePull
    echo "## Screenshots" >>$filePull
    echo "Screenshots:" >>$filePull

}

createPullRequest() {

    local repoPull=$1
    local branch=$2
    local title=$3

    local body=$(cat $filePull | sed -e s/#/\%23/g | sed -e s/\ /\%20/g | sed -z s/\\n/\%0A/g) # | tr "\n" "%0A" | tr " " "%20")"
    local assignees=rogerio-regis
    local reviewers=luiz-correia

    google-chrome --disable-gpu --disable-software-rasterizer --new-window "https://github.azc.ext.hp.com/$repoPull/compare/$branch?expand=1&title=$title&body=$body&reviewers=$reviewers&assignees=$assignees"

}
chooseReason() {
    local title=$*

    reasonList=("Fixing bugs" "Implementing New feature" "Creating Release" "Inserting cherry picks commits" "Improving Documentation")

    doDisplay 6 "Select the reason for this PR:"
    select ret in "${reasonList[@]}" "Other Reason"; do
        case $ret in
        "Other Reason")
            read -p "Enter the reason: " reason
            break
            ;;
        *)
            reason=$ret
            break
            ;;
        esac
    done
    echo $reason
}

chooseDescripion() {
    local title=$*

    fileSize=$(stat --printf="%s" $fileDesc)

    if [ $fileSize -eq 0 ]; then
        echo "#### $title" >$fileDesc

        while read line; do
            echo "> - $line" >>$fileDesc
        done < <(git log | grep $jiraIssuer | grep -vw "Merge" | sed -e s/$jiraIssuer//)
    fi

    doDisplay 6 "Use vi editor to edit the description"
    sleep 3
    local ok=0
    while [ $ok -eq 0 ]; do
        vi $fileDesc
        cat $fileDesc

        doDisplay 6 "Do you agree this description?"
        select ret in "Yes" "No" "Exit"; do
            case $ret in
            Yes)
                ok=1
                break
                ;;
            No)
                break
                ;;
            Exit)
                exit -1
                ;;

            esac
        done
    done
    return

    index=0
    descList=()
    while read line; do
        descList[index]="$line"
        ((index++))
    done < <(git log | grep $jiraIssuer | grep -vw "Merge" | sed -e s/$jiraIssuer/.../)

    index=0
    descOutList=()
    local ok=0
    while [ $ok -eq 0 ]; do
        doDisplay 6 "Select the description for this PR:"
        select ret in "Exit" "Other" "${descList[@]}"; do
            case $ret in
            "Exit")
                desc=""
                if ((${#descOutList[@]} == 0)); then
                    read -p "Enter the desc: " desc
                fi
                ok=1
                break
                ;;
            "Other")
                read -p "Enter the desc: " desc
                break
                ;;
            *)
                desc=$ret
                for i in "${!descList[@]}"; do
                    if [[ "${descList[i]}" = "$ret" ]]; then
                        unset 'descList[i]'
                    fi
                done
                break
                ;;
            esac

        done
        descOutList[index]="$desc"
        ((index++))
    done
    echo dddddd "${descOutList[@]}" >$fileDesc
    vi $fileDesc
    descx=$(cat $fileDesc)
    echo $descx
    doDisplay 6 "Select option for description?"
    select ret in "Agree" "Disagree" "${descOutList[@]}"; do
        case $ret in
        Yes)
            break
            ;;
        No)
            continue
            ;;
        esac
    done

    echo $reason
}

parse_git_branch() {
    git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/'
}

switchBranch() {

    git fetch --all

    descList=()
    while read line; do
        descList[index]="$line"
        ((index++))
    done < <(git branch --all | grep $jiraIssuer/)

    doDisplay 5 "Do you want switch to $jiraIssuer branch?"
    select ret in "No" "${descList[@]}" "Other"; do
        case $ret in
        No)
            exit -1
            ;;
        Other)
            read -p "Enter the branch name: " repoBranch
            countBranch=$(git branch --all | grep $repoBranch | wc -l)
            if [ $countBranch -eq 0 ]; then
                doDisplay 1 "Invalid branch: $repoBranch. Try again"
                exit -1
            fi
            break
            ;;
        *)
            repoBranch=$ret
            break
            ;;
        esac
    done

    git checkout -b $repoBranch
    git pull
    branchPull=$(parse_git_branch)
}

#**************************************************************************************************
# MAIN
#**************************************************************************************************
repoName=$(basename -s .git "$(git config --get remote.origin.url)")
doDisplay 2 On repository [$repoName] executing[$version]: $0 $*

if [ ! -d ".git" ]; then
    doDisplay 1 "Execute this script on repository [$repoName] home dir"
    exit -4
fi

if [ ! -f $fileJiraToken ]; then
    doDisplay 1 "Jira token not found. Execute tools/installJiraToken.sh"
    exit -1
fi

branchPull=$(parse_git_branch)

countBranch=$(echo $branchPull | grep $jiraIssuer/ | wc -l)
if [ $countBranch -eq 0 ]; then
    doDisplay 1 "Current branch does not match with jira issue: $jiraIssuer"
    switchBranch
fi

repoPull=$(git config --get remote.origin.url | cut -d":" -f2 | cut -d"." -f1)
doDisplay 6 "==> Creating Pull Request for ... "
doDisplay 6 "       repository: $repoPull "
doDisplay 6 "       branch: $branchPull "
doDisplay 6 "       Jira: $jiraIssuer "

doDisplay 6 "Do you agree with this information?"
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

countLog=$(git log --oneline | grep -c $jiraIssuer)
if [ $countLog -eq 0 ]; then
    doDisplay 1 "Jira issue: $jiraIssuer not found commits message on branch: $branchPull"
    git fetch --all
    countBranch=$(git branch --all | grep $jiraIssuer | wc -l)
    if [ $countBranch -eq 0 ]; then
        doDisplay 1 "No branch issue: $jiraIssuer found on git repository"
        exit -1
    fi
    switchBranch
fi

git pull

token=$(cat $fileJiraToken | grep Token: | cut -d":" -f2)
email=$(cat $fileJiraToken | grep Email: | cut -d":" -f2)
name=$(cat $fileJiraToken | grep Name: | cut -d":" -f2)

jiraRet=$(curl --request GET --header 'Accept: application/json' --user $email:$token \
    --url https://hp-jira.external.hp.com/rest/api/latest/search?jql=key=$jiraIssuer 2>/dev/null)

#echo $jiraRet
ret=$(echo $jiraRet | grep -oe "Authentication Failure" | wc -l)
if [ $ret -eq 1 ]; then
    doDisplay 1 "Jira authentication failure. Execute tools/installJiraToken.sh"
    exit -1
fi

title=$(echo $jiraRet |
    jq -r 'paths(scalars | true) as $p  | [ ( [ $p[] | tostring ] | join(".") ), ( getpath($p) | tojson )] | join(": ")' | grep issues.0.fields.summary |
    cut -d":" -f2 | sed -e 's/\"//g' -e 's/ //')
if [ -z "$title" ]; then
    doDisplay 1 "Jira issue: $jiraIssuer not found on Jira"
    exit -1
fi

title="$jiraIssuer $title"
doDisplay 6 "Title: $title"

preparePullRequest $jiraIssuer "$title"

createPullRequest $repoPull $branchPull "$title"

branchPull=$(parse_git_branch)
doDisplay 6 "Do you want delete local branch: $branchPull?"
select ret in "Yes" "No"; do
    case $ret in
    Yes)
        git checkout $branchMaster
        git branch -D "$branchPull"
        git pull
        break
        ;;
    No)
        exit
        ;;
    esac
done

# google-chrome --disable-gpu --disable-software-rasterizer --new-window https://hp-jira.external.hp.com/browse/TSW-202189
# https://hp-jira.external.hp.com/plugins/servlet/samlsso?redirectTo=%2Fsecure%2FRapidBoard.jspa%3FrapidView%3D37430%26quickFilter%3D102163
