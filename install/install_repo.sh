#!/bin/bash
source dependencies.sh

export SHELL=/bin/bash

version="1.0.1"

doDisplay() {
    local color=$1

    shift
    local msg=$*
    echo "$(tput setaf $color)$msg $(tput sgr0)"

    #read -p "Press enter to continue"
}

installApplication() {

    local package=$1
    doDisplay 6 Install application .... package: $package

    sudo apt-get -y install $package

    doDisplay 5 "$(apt-cache show $package | grep 'Package\|Version')"
}

installSubModule() {

    doDisplay 6 Verifying submodule ...

    git submodule update --init --recursive
    git submodule update --remote
    git fetch --all

    cd trust-agent-ipc
    git scheckout master
    git pull
    cd -

}

building() {

    local buildDir=$1
    doDisplay 6 Building on ... $buildDir

    if [ ! -d $buildDir ]; then
        mkdir -p $buildDir
    fi

    pushd $buildDir
    cmake -G Ninja -D CMAKE_BUILD_TYPE=RelWithDebInfo ../..

    # ninja clean
    ninja

    doDisplay 6 "Running unit test ..."
    ctest --label-exclude EXCLUDED_TEST

    doDisplay 6 "Generation rpm package ..."
    cpack

    popd

}

installDockers() {
    local container=$1

    doDisplay 6 Installing docker container ...: $container

    sudo docker pull $container
}

dockering() {

    installDockers docker.warehouse.teradici.com/docker/ubuntu-22.04-client_dependencies_wind_river_linux
    installDockers docker.warehouse.teradici.com/docker/ubuntu-20.04-client_dependencies
    installDockers docker.warehouse.teradici.com/docker/ubuntu-22.04-client_dependencies

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
}

installEnv() {

    local toolsDir=./tools
    local envDir=../../Environment-Setup

    if [ ! -d $toolsDir ]; then
        mkdir $toolsDir
    fi

    cd $toolsDir

    rm -rf execBuilds.sh
    rm -rf install_repo.sh

    ln -s $envDir/build/execBuilds.sh execBuilds.sh
    ln -s $envDir/tools/CMakeTarget.sh CMakeTarget.sh
    ln -s $envDir/install/install_repo.sh install_repo.sh
    ln -s $envDir/tools/installRPMFile.sh installRPMFile.sh
    ln -s $envDir/tools/executeNgrok.sh executeNgrok.sh
    ln -s $envDir/tools/sshCopyFile.sh sshCopyFile.sh

    cd - >/dev/null
}
#**************************************************************************************************
# Main
#**************************************************************************************************

if [ ! -f dependencies.sh ]; then
    doDisplay 1 "Fatal error: dependencies.sh not found"
    exit -1
fi
repoName=$(basename -s .git "$(git config --get remote.origin.url)")
doDisplay 2 On repository [$repoName] executing[$version]: $0 $*
doDisplay 6 "Installing $repoName project  ..."

if [ ! -d ".git" ]; then
    doDisplay 1 "Execute this script on repository [$repoName] home dir"
    exit -4
fi

installEnv

sudo apt-get -y remove needrestart

doDisplay 6 "Updating package manager(apt) ..."
sudo apt -y update
sudo apt -y upgrade

installApplication cmake
installApplication clang
installApplication clang-tidy
installApplication clang-format
installApplication ninja-build
installApplication valgrind
installApplication lcov
installApplication libpcsclite-dev

dockering
installDependencies # install dependencies from dependencies.sh

sudo apt-get -y install needrestart

git fetch --all
installSubModule
building build/RelWithDebInfo
