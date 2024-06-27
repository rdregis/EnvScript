# execBuilds.sh 
Execute builds for code verifying:
1) The script can only be executed in repository's root directory
1) Partial container name will do match with the installed containers (Look: Docker execution/containers)
1) Necessary packages and containers will be installed
1) Build directory will br created
1) Cleaning previous build use restart(-r) option
1) Do not interrupting execution and accept default value use goAhead (-g) option 

## Execution parameters

###### Usage: 
``` bash
	execBuilds.sh [ -h ] | [ -db <docker container> ] [ -r ]  [ -g ] <commands > [ -t <target name> ][ -b <build dir> ]
```

``` bash
	execBuilds.sh [ -h ] | [ -de <docker container> ] [ -g ]   
```
``` 
<commands >: 				<build> | <clang> | <coverage> | <formating> | <windriver>
							<address sanitizer> | <thread sanitizer> |  <unit test> | <valgrind> | <veracode> 
<build>:          			[ -bd ] 
<clang>:          			[ -cl ] 
<coverage>:	  				[ -cv [ -p <page directory> ] ]
<address sanitizer>:    	[ -as ]
<thread sanitizer>:     	[ -ts ]
<formating>:     			[ -ft ]
<unit test>:          		[ -ut [ -f <gtest filter> ] ]
<valgrind>:          		[ -vg ]
<veracode>:          		[ -vc ]
<windriver>:          		[ -wr ]

```
For more information about the parameters in this script, run it with the help (-h) parameter
``` shell
execBuilds.sh --help
```

## Examples
- Execution without Docker
	- Execution build coverage
		- ./tools/execBuilds.sh -cv
	- Execution build coverage filtering desired html page
		- ./tools/execBuilds.sh -cv -p platform_interface/src
	- Execution build address sanitizer
		- ./tools/execBuilds.sh -as 
	- Execution unit test filtering gtest
		- ./tools/execBuilds.sh -ut -f \*Input\*

- Execution on Docker (-db \<container\>)
	- Execution build coverage 
		- ./tools/execBuilds.sh -db ubuntu-22 -cv
	- Execution build coverage  filtering desired html page
		- ./tools/execBuilds.sh -db ubuntu-22 -cv -p platform_interface/src
	- Execution build address sanitizer
		- ./tools/execBuilds.sh -db ubuntu-22 -as 
	- Execution unit test filtering gtest
		- ./tools/execBuilds.sh -db ubuntu-22 -ut -f \*Input\*

- Execution only the Docker (-de \<container\>)
	- Execution build coverage 
		- ./tools/execBuilds.sh -de ubuntu-22

## Target name specification

The target name is an optional parameter that defines the module you want to check after the build is complete.

Using this parameter restricts the construction to the desired module, however, it increases the analysis speed.



## CMAKE specification
Cmake option used based on the command 

1) Build 
  	- ```cmake -G Ninja -D CMAKE_BUILD_TYPE=RelWithDebInfo```
1) Coverage 
  	- ```cmake -G Ninja -Wdev --warn-uninitialized -D CMAKE_BUILD_TYPE=Coverage```
1) Clang Tidy
	- ```CC=clang CXX=clang++ cmake -G Ninja -Wdev --warn-uninitialized -D CMAKE_BUILD_TYPE=Release -D CLANG_TIDY=on```
1) Formatting
	- ```cmake -G Ninja -Wdev --warn-uninitialized -D CMAKE_BUILD_TYPE=RelWithDebInfo```	
1) Address Sanitizer 
	- ```CC=clang CXX=clang++ cmake -G Ninja -Wdev --warn-uninitialized  -D CMAKE_BUILD_TYPE=asan```
1) Thread Sanitizer 
	- ```CC=clang CXX=clang++ cmake -G Ninja -Wdev --warn-uninitialized  -D CMAKE_BUILD_TYPE=tsan```	
1) Unit Tests 
	- ```make -G Ninja -D CMAKE_BUILD_TYPE=Debug```	
1) Vera Code 
	- ```cmake -G Ninja -Wdev --warn-uninitialized  -D CMAKE_BUILD_TYPE=veracode```
1) Valgrid 
	- ```cmake -G Ninja -D CMAKE_BUILD_TYPE=Debug```	
1) Wind River 
	- ```cmake -G Ninja -Wdev --warn-uninitialized -D CMAKE_TOOLCHAIN_FILE=../../cmake/toolchain/windriver-lts21.cmake -D CMAKE_BUILD_TYPE=release ```

## Docker execution

The script allows the execution of builds on docker with the -db parameter and also the execution of only docker with the -de parameter

In both cases, you must select the desired docker with the option -c \<docker name\>

## Docker containers
Container used on command. The container name must be passed to the script through the -c parameter. It can be the full name or part of it and in this case the script will try to mach the installed containers. In case of duplication, the user must decide what is desired from a list. See item "Questions for confirmation"

##### Wind River 
``` shell
 docker.warehouse.teradici.com/docker/<operation system>-client_dependencies_wind_river_linux 
```
##### Others
```shell 
docker.warehouse.teradici.com/docker/<operation system>-client_dependencies
```


## Questions for confirmation (goAhead)
The script will be asked following question and option goAhred (-g) wiil used default 
1) "Do you wish to install program: \<package\>?"
	- "Yes"/"No" (default: "No")
2) "Do you wish install Docker: \<container\>?"
	- "Yes"/"No" (default: "No")
3) "Which docker do you wish [\<container\>]?"
	- "\<list of containers\>/"Other"/"Exit"" (default: \<first of list\> )
4) "What type of docker do you wish [\<container\>]?"
	- "client_dependencies"/"client_dependencies_wind_river_linux"/"Other"/"Exit" (default: "Exit")
5) "Enter the the docker name:"
	- Enter container name
6) "Do you wish to create \<build directory\> directory on $(pwd)?"
	- "Yes"/"No" (default: "Yes")
7) "Do you wish to DELETE \<build directory\> directory on $(pwd)?"
	- "Yes"/"No"/"Exit" (default: "No")

## Build directory
To avoid conflicts, each command creates a directory, in the repository's root directory, to store the build data according to the list below.

These directories are prefixed with the name "buildFromScript"

1) Build=./buildFromScript/buildBld
1) Coverage=./buildFromScript/buildCoverage
1) Clang=./buildFromScript/buildClang
1) Address sanitizer=./buildFromScript/buildAddSanit
1) Thread sanitizer=./buildFromScript/buildTrdSanit
1) Vera code=./buildFromScript/buildVeraCode
1) Formatting=./buildFromScript/buildFormat
1) Wind River=./buildFromScript/buildWindRiver
1) Valgrind=./buildFromScript/buildValgrind
1) Unit Test=./buildFromScript/build

If the execution is done on docker the build directory 1s prefixed by "Docker_". Ex: ./buildFromScript/Docker_buildCoverage


