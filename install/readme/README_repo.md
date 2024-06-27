# install_repo.sh 


Installation applications and dependencies for new clone repository

1) Updating installed software
1) Necessary packages and dependencies will be installed
1) Installating docker containers and development applications 
1) Refresh submodules repositories
1) Building, testing and generate project package

NOTE: This script installs the depencencies for specific repository using the file "dependencies.sh" located at repository home directory

## Script execution



###### Usage: 
``` bash
bash install_repo.sh 
```

## Examples
	- bash install_repo.sh 

## Procedimentos

1) Set environment update and upgrate and dependencies
1) Install development applications
	- cmake
	- clang
	- clang-tidy
	- clang-format
	- ninja-build
	- valgrind
	- lcov
1) Install docker containers
	- docker.warehouse.teradici.com/docker/ubuntu-22.04-client_dependencies_wind_river_linux
    - docker.warehouse.teradici.com/docker/ubuntu-20.04-client_dependencies
    - docker.warehouse.teradici.com/docker/ubuntu-22.04-client_dependencies
1)Install repository dependencies
1) Refresh submodules repositories
1) Building repository
	- Compiling
	- Testing
	- Package binaries

