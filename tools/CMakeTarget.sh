#!/bin/bash

noMatch="/core-apis/|/trust-agent-ipc"

showTarget() {
    local file=$1
    local type=$2
    shift
    shift
    local target=$*

    for list in $target; do
        echo [${type}].${list} #$file
    done
}

filterTarget() {
    local file=$1
    local type=$2
    local filter=$3
    local field=$4

    local targetFiltered=$(grep $filter $file | cut -d "(" -f2 | cut -d " " -f$field | sort -t" " -u -k1,1)

    if [ ! -z "$targetFiltered" ]; then
        showTarget $file $type $targetFiltered
    fi
}

readTargetTest() {

    local targetDir=$1

    local index=0
    while read file; do
        echo $file
        filterTarget $file alib add_library 1
        filterTarget $file llib link_libraries 1
        filterTarget $file mock "TeraMock" 2
        filterTarget $file test "TeraTest" 2
        ((index++))
        #find -name "*.js" -not -path "./directory/*" -not -path "./build/*" -not -path "./buildFromScript/*" -not -path "./deps/*" -not -path "./node_modules/*" -not -path "./too
    done < <(find $targetDir -type f -name CMakeLists.txt -not \( -path "./buildFromScript/*" -o -path "./trust-agent-ipc/*" -o -path "./core-apis/*" -prune \))
    filesRead=$index
}
readTarget() {

    local targetDir=$1

    while read file; do
        filterTarget $file alib add_library 1
        filterTarget $file llib link_libraries 1
        filterTarget $file mock "TeraMock" 2
        filterTarget $file test "TeraTest" 2
    done < <(find $targetDir -type f -name CMakeLists.txt -not \( -path "$targetDir/buildFromScript/*" -o -path "$targetDir/trust-agent-ipc/*" -o -path "$targetDir/core-apis/*" -prune \))
}

selectTarget() {
    local target=$1
    local type=$2
    local targetDir=$3
    local buildDir=$4

    local targetSelected
    for ret in $(readTarget $targetDir | egrep $target | sort -u); do
        isTyped=$(echo $ret | grep -c "\[$type\]")
        if [ $isTyped -eq 0 ]; then
            continue
        fi
        if [ ! -z "$buildDir" ]; then
            targetType=$(echo $ret | sed -e "s/\[$type\]./${type}_/")
            isBuilt=$(find -L $buildDir -type f -perm -a=x -name $targetType | wc -l)
            if [ $isBuilt -eq 0 ]; then
                continue
            fi
        fi
        targetSelected=$(echo $targetSelected $ret)
    done

    echo $targetSelected
}
return 0

#**************************************************************************************************
#* For debug
#**************************************************************************************************
target="."
type="test"
targetDir="."
builsDir="./buildFromScript/buildUnitTest"

readTargetTest $targetDir
echo filesRead: $filesRead

#target="audio"
echo "What target do you wish select to [$target]?"

selTarget=$(selectTarget $target $type $targetDir $builsDir)
#selTarget=$(selectTarget $target $type $targetDir $builsDir)

echo filesRead: $filesRead
echo $(echo $selTarget | sed -e "s/\[$type\]./${type}_/g")

select ret in "Other" $selTarget; do
    case $ret in
    Other)
        read -p "Enter target: " selTarget
        break
        ;;
    *)
        selTarget=$(echo $ret | sed -e "s/\[$type\]./${type}_/")
        break
        ;;
    esac
done
echo xxxxxx $selTarget
