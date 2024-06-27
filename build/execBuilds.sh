#!/bin/bash +xv

# © Copyright 2023 HP Development Company, L.P

# Exit immediately if a command exits with a non-zero status.
# set -e

#source $(dirname $(find $HOME -type f -perm -a=x -name CMakeTarget.sh))/CMakeTarget.sh
source ./tools/CMakeTarget.sh
version="1.1.1"

vlgOptions="--leak-check=full --track-origins=yes" #  if you need repeat test use: --gtest_repeat=100
fileConf=".devBuild.conf"
envRepoDir=Environment-Setup

buildDirBase=./buildFromScript
buildCovDir=$buildDirBase/buildCoverage
buildClangDir=$buildDirBase/buildClang
buildAddSanitDir=$buildDirBase/buildAddSanit
buildTrdSanitDir=$buildDirBase/buildTrdSanit
buildVCodeDir=$buildDirBase/buildVeraCode
buildFormatDir=$buildDirBase/buildFormat
buildWindRiverDir=$buildDirBase/buildWindRiver
buildBldDir=$buildDirBase/buildBld
buildHelperStubDir=$buildDirBase/buildHelperStub

buildValgrindDir=$buildDirBase/buildValgrind
buildTestDir=$buildDirBase/buildUnitTest
buildDockerDir=./build
dkScript=dk_$(basename $0)

reset=0
inDkRun=0
goAhead=0
buildIndex=""
operation=null
buildOperation=
pageDir=
opTarget=
dkContainer=
opFilter=
dockerCmd=

showHelp() {
	# `cat << EOF` This means that cat should stop reading when EOF is detected
	cat <<EOF

Execute builds for code verifying: $version
Usage: $0 [ -h ] | [ -db <docker container> ] [ -r ]  [ -g ] <commands> [ -t <target name> ] [ -b <build dir> ]
Usage: $0 [ -h ] | [ -de <docker container> ] [ -g ]  

-h,  -help,        	--help          	Display help
-de  -dockerExe	       	--dockerExe   		Execute Docker container without command
-db  -dockerBld	       	--dockerBld    		Execute building on Docker container
-r						Reset/Clear history from build directory
-g						Go ahead (do not ask for confirmation)
-c <docker container>   			Docker container 
-t <target name>        			Target name execute
-b <build dir>					Directory where the build was made or will be

<commands >: 				<build> | <clang> | <coverage> | <formating> | <helper stub> | <windriver>
					<address sanitizer> | <thread sanitizer> |  <unit test> | <valgrind> | <veracode> 
<build>:          		[ -bd ] 
<clang>:          		[ -cl ] 
<coverage>:	  		[ -cv [ -p <page directory> ] ]
<address sanitizer>:    	[ -as ]
<thread sanitizer>:     	[ -ts ]
<formating>:     		[ -ft ]
<helper stub>:     		[ -hs ]
<unit test>:          		[ -ut [ -f <gtest filter> ] ]
<valgrind>:          		[ -vg ]
<veracode>:          		[ -vc ]
<windriver>:          		[ -wr ]

	-f <gtest filter>               Filtering tests to execution (--gtest_filter)
	-p <page directory>             Html output page directory where desired page is located

-bd  -build        --build       	Build generation
-cv  -coverage     --coverage           Code coverage report
-cl  -clang        --clang              Clang tidy report
-as  -addSanit     --addSanit		Address sanitizer report
-ts  -trdSanit     --trdSanit           Thread sanitizer report
-ft  -format       --format	        Formatting report
-hs  -helperStub   --helperStub         Helper stub building
-ut  -unitTest     --unitTest           Unit Test execution 
-vg  -valgrind     --valgrind           Valgrind verifying report
-vc  -veraCode     --veraCode           Vera Code verifying report
-wr  -windRiver    --windRiver          Wind River building code

New build directory will be create following this
	bd=$buildBldDir		cl=$buildClangDir		as=$buildAddSanitDir	
	ts=$buildTrdSanitDir	vc=$buildVCodeDir	cv=$buildCovDir	
	vg=$buildValgrindDir	ft=$buildFormatDir 	ut=$buildTestDir
	wr=$buildWindRiverDir	hs=$buildHelperStubDir
Note: Builds created on docker will be prefixed by : Docker_ 
	
Pre-requesits: 
	The script must be executed in the repository's home directory
EOF
	# EOF is found above and hence cat command stops reading. This is equivalent to echo but much neater when printing out.
}

doDisplay() {
	local color=$1
	shift
	local msg=$*
	echo "$(tput setaf $color)$msg $(tput sgr0)"
}

getCommonsParameters() {

	while true; do
		case "$1" in
		-b)
			shift
			buildOperation=$buildDirBase/$1
			;;
		-t)
			shift
			opTarget=$1
			;;
		-f)
			shift
			opFilter=$1
			;;
		-i)
			shift
			buildIndex=$1
			;;
		*)
			if [ "$1" == "" ]; then
				return
			fi
			doDisplay 1 "Invalid parameter: $* Use $0: <commands> [ -b <build dir> ]"
			showHelp
			exit -2
			break
			;;
		esac
		shift
	done

}

getCoverageParameters() {

	while true; do
		case "$1" in
		-p)
			shift
			pageDir=$1
			;;
		*)
			if [ "$1" == "" ]; then
				return
			fi
			getCommonsParameters $1 $2
			shift
			;;
		esac
		shift
	done

}

getUnitTestParameters() {

	local allPars=$*
	while true; do
		case "$1" in
		-f)
			shift
			opFilter=$1
			;;
		-i)
			shift
			buildIndex=$1
			;;
		*)
			if [ "$1" == "" ]; then
				return
			fi
			getCommonsParameters $1 $2
			shift
			;;
		esac
		shift
	done

}

getDockerParameters() {

	local dkType=$1
	shift
	while true; do
		case "$1" in
		-t)
			[[ $dkType == "de" ]] && doDisplay 1 "Invalid parameter -t for Docker: $*" && showHelp && exit -2
			shift
			opTarget=$1
			;;
		-g)
			goAhead=1
			;;
		*)
			if [ "$1" != "" ]; then
				[[ $dkType == "de" ]] && doDisplay 1 "Invalid parameter for Docker: $*" && showHelp && exit -2
				dockerCmd=$*
				break
			else
				[[ $dkType == "de" ]] && break
				doDisplay 1 "Missing parameter for Docker: $1 Use $0: -de/db <docker name> <command> "
				showHelp
				exit -2
			fi
			break
			;;
		esac
		shift
	done

	if [ -z $dkContainer ]; then
		doDisplay 1 "Missing docker 'container' parameter"
		showHelp
		exit -2
	fi

}
getRunParameters() {

	while true; do
		case "$1" in
		-h | --help)
			showHelp
			exit 0
			;;

		-g)
			goAhead=1
			;;
		-r)
			reset=1
			;;
		--dkRun)
			inDkRun=1
			;;
		-bd | --build)
			operation=bld
			buildOperation=$buildBldDir
			shift
			getCoverageParameters $*
			break
			;;
		-cv | --coverage)
			operation=cov
			buildOperation=$buildCovDir
			shift
			getCoverageParameters $*
			break
			;;
		-db | --dockerBld)
			operation=dkb
			buildOperation=$buildDockerDir
			shift
			dkContainer=$1
			shift
			getDockerParameters "db" $*
			break
			;;
		-de | --dockerExe)
			operation=dke
			inDkRun=1
			buildOperation=$buildDockerDir
			shift
			dkContainer=$1
			shift
			getDockerParameters "de" $*
			break
			;;
		-cl | --clang)
			operation=clt
			buildOperation=$buildClangDir
			shift
			getCommonsParameters $*
			break
			;;
		-as | --addSanit)
			operation=ast
			buildOperation=$buildAddSanitDir
			shift
			getCommonsParameters $*
			break
			;;
		-ft | --format)
			operation=fmt
			buildOperation=$buildFormatDir
			shift
			getCommonsParameters $*
			break
			;;
		-hs | --helperStub)
			operation=hst
			buildOperation=$buildHelperStubDir
			shift
			getCommonsParameters $*
			break
			;;
		-ts | --trdSanit)
			operation=tst
			buildOperation=$buildTrdSanitDir
			shift
			getCommonsParameters $*
			break
			;;
		-ut | --unitTest)
			operation=unt
			buildOperation=$buildTestDir
			shift
			getUnitTestParameters $*
			break
			;;
		-vc | --veraCode)
			operation=vcd
			buildOperation=$buildVCodeDir
			shift
			getCommonsParameters $*
			break
			;;
		-vg | --valgrind)
			operation=vlg
			buildOperation=$buildValgrindDir
			shift
			getCommonsParameters $*
			break
			;;
		-wr | --windRiver)
			operation=wrv
			buildOperation=$buildWindRiverDir
			shift
			getCommonsParameters $*
			break
			;;
		*)
			doDisplay 1 "Invalid parameter: $* for script. Use $0 [-de/db <docker name>] <commands>"
			showHelp
			exit -2
			break
			;;
		esac
		shift
	done

	if [ -z $buildOperation ]; then
		doDisplay 1 "Error: Build operation is not set"
		exit -2
	fi

}

doSelect() {

	local goSelect=$1
	local goDefault=$2

	shift
	shift
	local options=$*

	if [ $goSelect -eq 1 ]; then
		echo $goDefault
		return
	fi

	select ret in $options; do
		if [ ! -z $ret ]; then
			optRet=$(echo $options | grep -c $ret)
			if [ $optRet -eq 1 ]; then
				echo $ret
				break
			fi
		fi
	done
}

installPackage() {

	local package=$1
	local upgrate=$2

	local ret=$(apt list --installed $package 2>/dev/null | grep -c $package)

	local sudoApp=sudo
	if [ $inDkRun -eq 1 ]; then
		sudoApp=""
	fi

	if [ $ret -eq 0 ]; then
		doDisplay 6 "Do you wish to install program: $package?"
		yn=$(doSelect $goAhead No "Yes" "No")
		case $yn in
		Yes)
			doExecute $sudoApp apt -y update
			if [ $upgrate -eq 1 ]; then
				doExecute $sudoApp apt -y upgrade
			fi
			doExecute $sudoApp apt -y install $package
			;;
		No)
			doDisplay 6 "Exiting by user request"
			exit -3
			;;
		esac
	fi

	doDisplay 6 "Verifing installed package:... $package"
	doDisplay 5 "$(apt-cache show $package | grep 'Package\|Version')"

}

executeUnitTest() {

	local buildDir=$1
	local testTarget=$2
	local testFilter=$3

	if [ -z $testTarget ]; then
		testTarget=".*"
	else
		local fRet=$(find . -name $testTarget | grep -c $testTarget)
		if [ $fRet -eq 0 ]; then
			doDisplay 1 "Unit test Target: $testTarget is not found: $buildDir"
			exit -4
		fi
	fi

	if [ ! -z $testFilter ]; then
		gtestFilter=--gtest_filter=$testFilter
	fi

	local testNumber=0
	for file in $(find -L . -type f -perm -a=x | grep -e "test/" -e "tests/" | grep "$testTarget"); do
		local count=$(basename $file | grep -v "dockerized" | grep -c "^test_")
		if [ $count -eq 0 ]; then
			continue
		fi
		testNumber=$((testNumber + 1))
		doDisplay 6 "Testing target:[$testNumber] [$testTarget] ... : $file"
		doExecute $file --gtest_list_tests $gtestFilter
		doExecute $file $gtestFilter
	done

	doDisplay 6 "Executed [$testTarget] [$testNumber] unit tests suits"

	#use to show only the test name
	#doExecute `find . -name $testTarget` --gtest_brief=1 $gtestFilter
}

installDocker() {

	local newContainer=$1

	doDisplay 6 "Do you wish install Docker: $newContainer?"

	yn=$(doSelect $goAhead No "Yes" "No")
	case $yn in
	Yes)
		local dRet=$(docker image list $newContainer | grep -c $newContainer)
		if [ $dRet -gt 0 ]; then
			doDisplay 6 "Docker container: $newContainer already exist"
			exit -4
		fi
		docker pull $newContainer
		if [ "$?" == "0" ]; then
			doDisplay 6 "Docker container: [$newContainer] will be mounted"
			dkContainer=$newContainer # update docker container parameter
		else
			doDisplay 1 "Error: $? on install docker container: [$newContainer]"
			exit -4
		fi
		;;
	No)
		doDisplay 6 "Exiting by user request"
		exit -3
		;;
	esac
}

prepareDocker() {

	local container=$1
	local dockerCmd=$2

	local dRet=0
	local dRet=$(docker image list "$container" | grep -c "$container")
	if [ $dRet -gt 0 ]; then
		doDisplay 6 "Docker container: $container will be mounted"
		return
	fi

	local dockerFilter=".*" # default
	if [ "$dockerCmd" == "-wr" ]; then
		dockerFilter=client_dependencies_wind_river_linux
	fi

	local dockerName=
	local repoIndex=0
	doDisplay 6 "Which docker do you wish [$container]?"
	for repo in $(docker image list | grep -v REPOSITORY | grep $container | grep "$dockerFilter" | sort -k 1 | awk '{print $1}'); do
		repoIndex=$((repoIndex + 1))
		if [ $repoIndex -eq 1 ]; then
			repoFirst=$repo
		fi
		dockerName=$(echo $dockerName $repo)
	done

	retContainer=$(doSelect $goAhead "$repoFirst" $dockerName "Other" "Exit")
	case $retContainer in
	Exit)
		doDisplay 6 "Exiting by user request"
		exit -3
		;;
	Other)
		doDisplay 6 "What type of docker do you wish [$container]?"
		dockerType=$(echo "client_dependencies" "client_dependencies_wind_river_linux")
		typeContainer=$(doSelect $goAhead "Exit" $dockerType "Other" "Exit")
		case $typeContainer in
		Exit)
			doDisplay 6 "Exiting by user request"
			exit -3
			;;
		Other)
			doDisplay 6 "Enter the the docker name:"
			read newContainer
			installDocker $newContainer
			;;
		*)
			newContainer=docker.warehouse.teradici.com/docker/${container}-$typeContainer
			installDocker $newContainer
			;;
		esac
		;;
	*)
		doDisplay 6 "Dockter container: $retContainer will be mounted"
		dkContainer=$retContainer # update docker container parameter
		;;
	esac

	for dockerId in $(docker image list | grep -v REPOSITORY | awk '{print $3}'); do
		dockerTag=$(docker image list | grep -v REPOSITORY | grep $dockerId | awk '{print $2}')
		if [ "$dockerTag" == "<none>" ]; then
			dockerName=$(docker image list | grep -v REPOSITORY | grep $dockerId | awk '{print $1}')
			doDisplay 6 Remove unused docker ...: $dockerName $dockerId
			docker rmi -f $dockerId
		fi
	done

	doDisplay 6 Listing docker ...
	docker image list

	repoIndex=0
	for repo in $(docker image list | grep -v REPOSITORY | sort -k 1 | awk '{print $1}'); do
		repoIndex=$((repoIndex + 1))
		if [ $repo == $container ]; then
			break
		fi
	done

	for repo in $(docker image list | grep -v REPOSITORY | grep -w $dkContainer | sort -k 1 | awk '{print $1}'); do
		repoIndex=$(docker image list | grep -v REPOSITORY | grep -w $dkContainer | awk '{print $3}')
		repoIndex=${repoIndex:7:5}
	done

	buildIndex=$repoIndex
}

trapIntSignal() {
	echo .
	doDisplay 3 [$0] "Exiting by Ctrl-C Signal ..."

	sleep 1

	exit -1
}

doExecuteShell() {

	local command=$*

	doDisplay 6 "==> /bin/bash -c $command"
	/bin/bash -c "$command"

	exitStatus=$?

	if [ $exitStatus -ne 0 ]; then
		doDisplay 1 "*************************************************************"
		doDisplay 1 "* Error on execute $command"
		doDisplay 1 "*************************************************************"
		exit -1
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

runDocker() {

	local container=$1
	local mountDir=$2
	local cdDir=$3

	shift
	shift
	shift
	local command=$*

	local user=$(id -u):$(id -g)
	doDisplay 6 "Docker executed over user: $user"

	local dockerMount="$mountDir:/root/${mountDir##~/}"
	local mountDirEnv="$mountDir/../$envRepoDir"
	local dockerMountEnv="$mountDirEnv:/root/${mountDirEnv##~/}"
	(doExecute docker run --rm --env="DISPLAY" --name="${container##*/}" --security-opt apparmor=unconfined \
		-e "repoDocker=$container" -v ~/.ccache:/root/.ccache -v ~/.ssh:/root/.ssh -v "$dockerMount" -v "$dockerMountEnv" \
		-it -w ${dockerMount#*:}/$cdDir "$container" $command)

}

createBuildDirectory() {

	local buildDir=$1
	local operation=$2
	local buildType=$3

	doDisplay 6 "Creating $buildDir directory"
	doExecute mkdir -p $buildDir
	echo $operation $buildType $repoDocker >$buildDir/$fileConf
	wasCreatedDir=1
}

verifyCreateBuildDirectory() {

	local buildDir=$1
	local operation=$2
	local buildType=$3

	doDisplay 6 "Do you wish to create $buildDir directory on $(pwd)?"

	yn=$(doSelect $goAhead Yes "Yes" "No")
	[[ $goAhead -eq 1 ]] && echo -e $yn
	case $yn in
	Yes)
		createBuildDirectory $buildDir $operation $buildType
		;;
	No)
		doDisplay 6 "Exiting by user request"
		exit -3
		;;
	esac

}

prepareBuild() {

	local buildDir=$1
	local operation=$2
	local buildType=$3

	shift
	shift
	shift
	local buildCmake="$*"

	local wasCreatedDir=0

	if [ -d $buildDir ]; then
		if [ $reset -eq 1 ]; then
			doDisplay 6 "Do you wish to DELETE $buildDir directory on $(pwd)?"

			yn=$(doSelect $goAhead No "Yes" "No" "Exit")
			[[ $goAhead -eq 1 ]] && echo -e $yn
			case $yn in
			Yes)
				doDisplay 6 "Deleting $buildDir directory"
				doExecute rm -rf $buildDir
				createBuildDirectory $buildDir $operation $buildType
				;;
			No)
				doDisplay 6 "Directory not deleted by user request"
				;;
			Exit)
				doDisplay 6 "Exiting by user request"
				exit -3
				;;
			esac
		fi
	fi

	if [ ! -d $buildDir ]; then
		verifyCreateBuildDirectory $buildDir $operation $buildType
	fi

	if [ -f $buildDir/$fileConf ]; then
		local sameBuildType=$(cat $buildDir/$fileConf | cut -d " " -f 2 | grep -c $buildType)
		if [ $sameBuildType -ne 1 ]; then
			doDisplay 1 "Build directory: $buildDir is not being used by this operation: [$operation] $buildType-$(cat $buildDir/$fileConf | cut -d " " -f 2)"
			exit -4
		fi

		local sameDkRepo=$(cat $buildDir/$fileConf | cut -d " " -f 3 | grep -c $repoDocker)
		if [ $sameDkRepo -ne 1 ]; then
			doDisplay 1 "Build directory: $buildDir is being used by docker: $(cat $buildDir/$fileConf | cut -d " " -f 3)"
			exit -4
		fi
	fi

	doDisplay 6 "Building on $buildDir ... "
	doExecute cd $buildDir

	if [ $wasCreatedDir -eq 1 ]; then
		doExecuteShell "$buildCmake -Wno-dev ../.."
		return
	fi

	if [ ! -f $fileConf ]; then
		doDisplay 1 "Missing build file config: $fileConf. Restart execution use -r parameter"
		exit -4
	fi
	if [ ! -f CMakeCache.txt ]; then
		doDisplay 1 "Missing CMakeCache.txt. Restarting execution"
		doExecuteShell "$buildCmake -Wno-dev ../.."
		return
	fi

	local cmakeBuildType=$(cat CMakeCache.txt | grep CMAKE_BUILD_TYPE | cut -d"=" -f 2)
	local sameBuildType=$(cat $fileConf | cut -d " " -f 2 | grep -c $cmakeBuildType)
	if [ $sameBuildType -ne 1 ]; then
		doDisplay 1 "Build directory: $buildDir is not being used by this build type: $cmakeBuildType"
		exit -4
	fi

	if [ $reset -eq 1 ]; then
		doExecute ninja clean
		doExecuteShell "$buildCmake -Wno-dev ../.."
	fi

}

doExecNinja() {

	local ninjaTarget=$1
	shift
	local ninjaPar=$*

	git submodule update --remote
	git submodule foreach git pull origin master

	if [ ${#ninjaTarget} -eq 0 ]; then
		doExecute ninja $ninjaPar
		return
	fi

	local ok=0
	while [ $ok == 0 ]; do
		selTarget=$(echo $(selectTarget "." test $homeRepoDir) | sed -e "s/\[test\]./test_/g")
		isSelTarget=$(echo $selTarget | sed -e "s/ /\n/g" | grep -wc $ninjaTarget)
		if [ $isSelTarget -eq 1 ]; then
			break
		fi
		ninjaTargetSel=$(echo $(selectTarget $ninjaTarget test $homeRepoDir) | sed -e "s/\[test\]./test_/g")
		doDisplay 6 "Target:[$ninjaTarget] is not found"
		doDisplay 6 "Do you wish to select another target?"
		yn=$(doSelect $goAhead No "No" "Other" $ninjaTargetSel)
		[[ $goAhead -eq 1 ]] && echo -e $yn
		case $yn in
		No)
			doDisplay 6 "Exiting by user request"
			exit -3
			;;
		Other)
			read -p "Enter target: " ninjaTarget
			;;
		*)
			ninjaTarget=$yn
			ok=1
			;;
		esac

	done

	# Update global variable opTarget
	opTarget=$ninjaTarget

	doExecute ninja $ninjaTarget $ninjaPar

}

packing() {

	local buildDir=$1
	local operation=$2
	local buildType=$3

	cleanPackage deb

	doExecute cpack

	cd - >/dev/null
	doDisplay 6 "Generated binaries: "
	find -L $buildDir -type f -perm -a=x -mmin -1 | grep -v '.debug'

	if [ ! -z $buildIndex ]; then
		# not installed on docker
		return
	fi
	for file in $(
		find $buildDir -name "*.deb" | grep -v DEB
	); do
		doDisplay 6 "Do you wish install package...: $(basename $file)"
		stat $file

		yn=$(doSelect $goAhead No "Yes" "No")
		[[ $goAhead -eq 1 ]] && echo -e $yn
		case $yn in
		Yes)
			doExecute /usr/bin/sudo dpkg -i $file
			;;
		No)
			break
			doDisplay 6 "Exiting by user request"
			exit -3
			;;
		esac
	done

}

doCoverage() {

	doDisplay 6 "Execute Code coverage ..."

	if [ ! -d code-coverage ]; then
		doExecNinja "" -v code-coverage
	elif [ $reset -eq 1 ]; then
		doExecNinja "" -v code-coverage
	fi

	cd code-coverage

	local coveragePage=./index.html

	if [ ! -z $pageDir ]; then
		coveragePage=$(find . -name index.html | grep $pageDir/index.html)
		local fRet=$(echo $coveragePage | grep -c $pageDir/index.html)
		if [ $fRet -eq 0 ]; then
			doDisplay 1 "Coverage page : $pageDir is not found: $PWD"
			exit -4
		fi
	fi

	doExecute xdg-open $coveragePage
}

doExecValgrid() {

	local opTarget=$1
	local gtestFilter=$2
	shift
	shift
	local vlgOptions=$*

	if [ -z $opTarget ]; then
		opTarget=".*"
	else
		local fRet=$(find . -name $opTarget | grep -c $opTarget)
		if [ $fRet -eq 0 ]; then
			doDisplay 1 "Valgrind Target: $opTarget is not found: $buildDir"
			exit -4
		fi
	fi

	local testNumber=0
	for file in $(find -L . -type f -perm -a=x | grep -e "test/" -e "tests/" | grep "$opTarget"); do
		local count=$(basename $file | grep -v "dockerized" | grep -c "^test_")
		if [ $count -eq 0 ]; then
			continue
		fi
		testNumber=$((testNumber + 1))
		doDisplay 6 "Testing valgrind:[$testNumber][$opTarget] ... : $file"
		doExecute valgrind $vlgOptions $file $gtestFilter
	done

	doDisplay 6 "Executed [$opTarget] [$testNumber] valgrind tests suites"

}

cleanPackage() {

	local packType=$1

	doDisplay 6 "Removing previous package..."
	for file in $(
		find . -name "*.$packType"
	); do
		filePackage=$PWD/$file
		doDisplay 6 $(ls -l $filePackage)
		rm -rf $filePackage
	done

}

showRpmPackage() {

	cd -

	for file in $(
		find . -name "*.rpm" | grep -v RPM
	); do
		doDisplay 6 "Showing generated package...: $(file $file)"

		doExecute rpm -qlpv $file
	done

}

tranferToRemote() {

	local remoteHost=$1
	local remoteDir=$2
	local remoteUser=$3

	shift
	shift
	shift
	local command=$*

	doDisplay 6 "Do you wish install RPM file on remote host?"
	yn=$(doSelect $goAhead No "Yes" "No")
	case $yn in
	Yes)
		local rpmFile=$(find . -name "*.rpm" | grep -v RPM)

		doDisplay 6 "Installing RPM file: $rpmFile"
		while true; do
			# from ssh pharos@amdx86-64
			doDisplay 6 "From ssh pharos@amdx86-64 (pharos device)"
			doDisplay 6 "execute bash ./installRPMFile.sh"
			read -p "Enter remote connection string <host>:<port>: " hostAndPort
			ngrokHost=$(echo $hostAndPort | cut -d ":" -f 1) # host
			ngrokPort=$(echo $hostAndPort | cut -d ":" -f 2) # port
			count=$(nc -z -v -w5 $ngrokHost $ngrokPort 2>&1 | grep -c succeeded)
			if [ $count -eq 1 ]; then
				doExecute ./tools/installRPMFile.sh -t $rpmFile $ngrokHost $ngrokPort
				break
			fi
			doDisplay 1 "Remote host: [$hostAndPort] is not available"
		done
		;;
	No) ;;
	esac

}
#***********************************************************************
#*    Start here
#***********************************************************************

#debug
#read -p "Press enter to continue"

repoName=$(basename -s .git "$(git config --get remote.origin.url)")
doDisplay 2 On repository [$repoName] executing[$version]: $0 $*

trap 'trapIntSignal' SIGSEGV SIGINT SIGTERM
getRunParameters $*

if [ ! -d ".git" ]; then
	doDisplay 1 "Execute this script on repository [$repoName] home dir"
	exit -4
fi

homeRepoDir=$(pwd)

if [ ! -d $buildDirBase ]; then
	doExecute mkdir $buildDirBase
	doExecute chmod 777 $buildDirBase
fi

if [ -z $repoDocker ]; then
	repoDocker=$operation
fi

originBuildDir=$buildOperation
if [ $inDkRun -eq 1 ]; then
	buildOperation=$buildDirBase/Docker_$(basename $buildOperation)
	if [ ! -z $buildIndex ]; then
		buildOperation="${buildOperation}_${buildIndex}"
	fi
	#buildOperation="$buildDirBase/Docker_$(basename $buildOperation)_$([[ $buildIndex != 0 ]] && echo_$buildIndex)"
fi

case "$operation" in
bld)
	doDisplay 6 "Executing Building ..."
	installPackage gcc 1
	installPackage g++ 1
	buildCMake="cmake -G Ninja -D CMAKE_BUILD_TYPE=RelWithDebInfo"
	prepareBuild $buildOperation $operation "RelWithDebInfo" $buildCMake
	doExecNinja $opTarget
	executeUnitTest $buildOperation "$opTarget" "$opFilter"
	packing $buildOperation # generate  package
	;;
cov)
	doDisplay 6 "Executing Code Coverage  ..."
	installPackage lcov 1
	buildCMake="cmake -G Ninja -Wdev --warn-uninitialized -D CMAKE_BUILD_TYPE=Coverage"
	prepareBuild $buildOperation $operation "Coverage" $buildCMake
	doExecNinja $opTarget
	doCoverage
	;;
clt)
	doDisplay 6 "Executing Clang Tidy Validation ..."
	installPackage clang-tidy 1
	installPackage clang 1
	buildCMake="CC=clang CXX=clang++ cmake -G Ninja -Wdev --warn-uninitialized -D CMAKE_BUILD_TYPE=Release -D CLANG_TIDY=on"
	prepareBuild $buildOperation $operation "Release" $buildCMake
	doExecNinja $opTarget
	packing $buildOperation # generate  package
	;;
fmt)
	doDisplay 6 "Executing formating ..."
	installPackage clang-format-12 $([[ -z $buildIndex ]] && echo 1 || echo 0)
	buildCMake="cmake -G Ninja -Wdev --warn-uninitialized -D CMAKE_BUILD_TYPE=RelWithDebInfo"
	prepareBuild $buildOperation $operation "RelWithDebInfo" $buildCMake
	# doExecNinja $opTarget
	doExecNinja "" -j1 version format
	;;
hst)
	doDisplay 6 "Executing Building for platform helper stub..."
	installPackage gcc 1
	installPackage g++ 1
	buildCMake="cmake -G Ninja -D CMAKE_BUILD_TYPE=RelWithDebInfo -D BUILD_HELPER_STUB=true"
	prepareBuild $buildOperation $operation "RelWithDebInfo" $buildCMake
	doExecNinja $opTarget
	packing $buildOperation # generate  package
	;;
ast)
	doDisplay 6 "Executing Address Sanitizer ..."$1
	installPackage clang $([[ -z $buildIndex ]] && echo 1 || echo 0)
	buildCMake="CC=clang CXX=clang++ cmake -G Ninja -Wdev --warn-uninitialized  -D CMAKE_BUILD_TYPE=asan"
	prepareBuild $buildOperation $operation "asan" $buildCMake
	doExecNinja $opTarget
	packing $buildOperation # generate  package
	;;
tst)
	doDisplay 6 "Executing Thread Sanitizer ..."
	installPackage clang $([[ -z $buildIndex ]] && echo 1 || echo 0)
	buildCMake="CC=clang CXX=clang++ cmake -G Ninja -Wdev --warn-uninitialized  -D CMAKE_BUILD_TYPE=tsan"
	prepareBuild $buildOperation $operation "tsan" $buildCMake
	doExecNinja $opTarget
	packing $buildOperation # generate  package
	;;
unt)
	doDisplay 6 "Executing Unit Tests ..."
	buildCMake="cmake -G Ninja -D CMAKE_BUILD_TYPE=Debug"
	prepareBuild $buildOperation $operation "Debug" $buildCMake
	doExecNinja $opTarget
	executeUnitTest $buildOperation "$opTarget" "$opFilter"
	;;
vcd)
	doDisplay 6 "Executing Vera Code  ..."
	buildCMake="cmake -G Ninja -Wdev --warn-uninitialized  -D CMAKE_BUILD_TYPE=veracode"
	prepareBuild $buildOperation $operation "veracode" $buildCMake
	doExecNinja $opTarget
	;;
vlg)
	doDisplay 6 "Executing Valgrid Verify ..."
	installPackage valgrind $([[ -z $buildIndex ]] && echo 1 || echo 0)
	buildCMake="cmake -G Ninja -D CMAKE_BUILD_TYPE=Debug"
	prepareBuild $buildOperation $operation "Debug" $buildCMake
	doExecNinja $opTarget
	if [ ! -z $opFilter ]; then
		gtestFilter=--gtest_filter=$opFilter
	fi
	doExecValgrid "$opTarget" "$gtestFilter" $vlgOptions
	;;
wrv)
	doDisplay 6 "Executing Wind River  ..."
	installPackage rpm 0
	installPackage netcat 0
	if [ -z $buildIndex ]; then
		doDisplay 1 "Missing docker parameter(-db) for Wind River"
		exit -4
	fi
	buildCMake="cmake -G Ninja -Wdev --warn-uninitialized -D CMAKE_TOOLCHAIN_FILE=../../cmake/toolchain/windriver-lts21.cmake -D CMAKE_BUILD_TYPE=release "
	prepareBuild $buildOperation $operation "release" $buildCMake
	cleanPackage rpm
	doExecNinja "" package
	showRpmPackage
	tranferToRemote
	;;
dkb)
	doDisplay 6 "Executing building on docker ..."
	prepareDocker $dkContainer $dockerCmd
	#in path dir execute : cp $(whereis $0 | cut -d " " -f 2) $dkScript
	cp $0 $dkScript
	chmod 755 $dkScript
	dockerCommand="/bin/bash  $dkScript --dkRun  $([[ $reset == 1 ]] && echo "-r" || echo "") 
											$([[ $goAhead == 1 ]] && echo "-g" || echo "")  
											$([[ ! -z "$opTarget" ]] && echo "-t $opTarget" || echo "") $dockerCmd -i $buildIndex"
	doDisplay 6 "Executing docker command ..."
	runDocker $dkContainer $(pwd) "" $dockerCommand
	rm -f $dkScript
	;;
dke)
	doDisplay 6 "Executing docker ..."
	prepareDocker $dkContainer
	doDisplay 6 "Executing docker without command ..."
	buildOperation=$buildDirBase/Docker_$(basename $originBuildDir)$([[ ! -z $buildIndex ]] && echo _$buildIndex)
	runDocker $dkContainer $(pwd) $buildOperation
	;;
*)
	doDisplay 1 Operation unknown: $operation
	showHelp
	;;
esac

exit 0
