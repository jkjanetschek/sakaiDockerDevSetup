#!/bin/bash

#TODO
# use tomcat from tomcat:9-jdk17-temurin image

# !Important 
# performance problemns with docker desktop on windows -> run in linux native filessystem and not in mnt from windows



###########################
# versions by sakaiproject#
###########################   
SAKAI_MASTER='master' 	  #
SAKAI_25='25.x'	          #
###########################

######################
# Tomcat config		 #
######################
######################
TOMCAT_VERSION="9.0.102"
######################
TOMCAT_SOURCE_FILE_PREFIX="apache-tomcat-"
TOMCAT_EXTRACTED_BASENAME="${TOMCAT_SOURCE_FILE_PREFIX}""${TOMCAT_VERSION}"
# tomcat from docker image
######################
# Options			 #
######################
STARTUP="run"
#STARTUP="jdpa run"
######################
SKIP_TEST="true"
#SKIP_TEST="false"
######################
# Any extra options to pass to maven
MVN_EXTRA_OPTS="-Dmaven.plugin.validation=DEFAULT"
THREADS=10
#####################################
# Docker Images		 				#
#####################################
PROXY_CONTAINER="esplo/docker-local-ssl-termination-proxy"
MAVEN_CONTAINER="maven:3.9.9-eclipse-temurin-17"
TOMCAT_CONTAINER="tomcat:9-jdk17-temurin"
DATABASE_CONTAINER="mariadb:10.6"
## Network name
NETWORK_NAME="sakai-network"

###########################################################################
# Command line arguments												  #
#																		  #
# first argument specifies the release version by sakaiproject			  #
# second argument (optional) specifies name of checked out custom branch  # 
###########################################################################
SAKAI_VERSION=$1
CUSTOM_BRANCH=$2
echo "using sakai version: ${SAKAI_VERSION}.."
git_branch=$(git)
if [[ $1 == "${SAKAI_MASTER}" ]]; then
	echo "using version ${SAKAI_MASTER}"
elif [[ $1 == "${SAKAI_25}" ]]; then
	echo "using version ${SAKAI_25}"
else
	echo "no version specified"
	exit 1;
fi
####################
# check git branch #
####################
cd $(dirname "${BASH_SOURCE[0]}")/sakai/sakai > /dev/null
BASEDIR=$(pwd -L)
GIT=$(git branch --show-current)
cd - > /dev/null
echo "on branch ${GIT}.."
if [[ "${SAKAI_VERSION}" == "${GIT}" && -z "${CUSTOM_BRANCH}" ]]; then
	echo "branch and specified version align..."
elif [[ -n "${SAKAI_VERSION}" && -n "${CUSTOM_BRANCH}" && "${CUSTOM_BRANCH}" == "${GIT}" ]]; then
	echo "using custom branch ${CUSTOM_BRANCH} based on ${SAKAI_VERSION}"
else
	echo "branch and specified version do not match..."
	exit 1
fi
#############################################################################
#############################################################################


##########################################
# check docker	     					 #
# if using docker desktop start manually #
##########################################
##########################################
start_docker_deamon() {
	# Run sudo -v with a 15-second timeout
	# timeout runs command in a subprocess --> --foreground runs the command in the foreground,
	# allowing terminal input.
    if timeout --foreground 15 sudo -v; then
		# try to start docker via systemd or dockerd
		echo "Attempting to start Docker daemon..."
		systemctl start docker > /dev/null 2>&1  || 
		dockerd > /dev/null 2>&1 & 
		sleep 5
		docker info >/dev/null 2>&1
		return $?
	else
		echo "failed to get sudo permission";
		return 1;
	fi
}


echo "Check docker process..."
# throw error if docker is not available
DOCKER_INFO_ERROR=$(docker info >/dev/null 2>&1; echo $?)
if [[ "$DOCKER_INFO_ERROR" -ne 0 ]]; then
	start_docker_deamon
	if [[ $?  -eq 0 ]]; then
		echo "docker seems to be running now..."
	else
		echo "Attempting to start Docker daemon failed..."
		exit 1
	fi
fi

DOCKER_HOST=$(docker context inspect $(docker context show) | sed -n 's/.*"Host": "\(.*\)",/\1/p')
echo "using docker endpoint: ${DOCKER_HOST}"
DOCKER_KERNEL_VERSION=$(docker info | sed -n 's/.*Kernel Version: \([^ ]*\).*/\1/p')
echo "using kernel version endpoint: ${DOCKER_KERNEL_VERSION}"



# build sakai
source ./build_sakai.sh "${TOMCAT_SOURCE_FILE_PREFIX}" "${TOMCAT_VERSION}" "${SAKAI_VERSION}"
if [ $? -eq 0 ]; then
    echo "Build success --> starting sakai"
	# run sakai
    source ./run_sakai.sh "${TOMCAT_SOURCE_FILE_PREFIX}" "${TOMCAT_VERSION}" "${STARTUP}" "${DATABASE_CONTAINER}" "${TOMCAT_CONTAINER}"
else
    echo "Starting up docker container(s)-->sakai not started"
fi

