#! /bin/bash



### tomcat
TOMCAT_SOURCE_DIR="tomcat"
TOMCAT_SOURCE_FILE_SUFFIX=".tar.gz"
TOMCAT_SOURCE_FILE_PREFIX=$1

TOMCAT_VERSION=$2  #redundant, available here via source command  in main.sh
TOMCAT_ARCHIVE_FILENAME=${TOMCAT_SOURCE_DIR}/${TOMCAT_SOURCE_FILE_PREFIX}${TOMCAT_VERSION}${TOMCAT_SOURCE_FILE_SUFFIX}
TOMCAT_EXTRACTED_BASENAME=${TOMCAT_SOURCE_FILE_PREFIX}${TOMCAT_VERSION}


SAKAI_SOURCE_DIRECTORY_LOCATION=${BASEDIR}"/sakai/sakai"
SAKAI_DEPLOY_BASE_DIRECTORY=${BASEDIR}"/sakai/build"
SAKAI_DEPLOY_TARGET=${SAKAI_DEPLOY_BASE_DIRECTORY}/${TOMCAT_EXTRACTED_BASENAME}


MAVEN_BUILD_DATA=${BASEDIR}"/mavenBuildData"
MAVEN_BUILD_DOCKER=${BASEDIR}"/mavenBuildDocker"



container_check_and_rm() {
	# If an argument ($1) is provided, use that as the container name, otherwise fall back   to the default variable $MAVEN_CONTAINER 
    local CONTAINER_NAME=${1:-$MAVEN_CONTAINER}
    local CONTAINER_ID=$(docker inspect --format="{{.Id}}" ${CONTAINER_NAME} 2> /dev/null)
    if [[ "${CONTAINER_ID}" ]]; then
        echo "${CONTAINER_NAME} exists, removing previous instance"
    	docker stop ${CONTAINER_NAME} > /dev/null && docker rm ${CONTAINER_NAME} > /dev/null
    fi
}



##################################################################################
##################################################################################


# !! ${0} --> if source is used it returns location of bash /bin; use ${BASH_SOURCE[0]} instead -->  variable is specific to Bash and always refers to the current script, even when sourced
cd $(dirname "${BASH_SOURCE[0]}") > /dev/null
BASEDIR=$(pwd -L)
#  switches the current directory to the previously visited directory.
cd - > /dev/null


container_check_and_rm "sakai-tomcat"

echo "executing rm -r ${SAKAI_DEPLOY_BASE_DIRECTORY}"
rm -rf "${SAKAI_DEPLOY_BASE_DIRECTORY}"
mkdir ${SAKAI_DEPLOY_BASE_DIRECTORY}
echo "mkdir ${SAKAI_DEPLOY_BASE_DIRECTORY}"
tar -xzf "${TOMCAT_ARCHIVE_FILENAME}" -C "${SAKAI_DEPLOY_BASE_DIRECTORY}"
if [[ $? -ne 0 ]]; then
	echo "unpacking tomcat"
	exit 1
fi







echo "SAKAI_DEPLOY_TARGET=${SAKAI_DEPLOY_TARGET}"
echo "SAKAI_SOURCE_DIRECTORY_LOCATION=${SAKAI_SOURCE_DIRECTORY_LOCATION}"
echo "MAVEN_BUILD_DATA=${MAVEN_BUILD_DATA}"

# put comamnd inside '' quotes for lazy evaluation; when script is sourced or run, it executes all top-level commands immediately:  command substitution is evaluated during variable assignment,
SUDO_USER_CMD='apt update && apt install -y sudo && echo "$(whoami) ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && '
SET_JAVA_HOME='bash -c export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which javac)))) && echo $JAVA_HOME && '
SUDO_WHOAMI='sudo -u $(whoami) '
SAKAI_26_BUILD_DEPENDENCIES=""
if [[ ${SAKAI_VERSION} == ${SAKAI_MASTER} ]]; then
	#SAKAI_26_BUILD_DEPENDENCIES="apk add --no-cache nss libstdc++ gdk-pixbuf cairo alsa-lib libx11 libcurl libjpeg-turbo libpng libwebp ffmpeg ttf-freefont zlib libxcomposite libxdamage libxext libxfixes libxrandr libxrender libxtst libc6-compat chromium && "
	SAKAI_26_BUILD_DEPENDENCIES="apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0 \
    libnss3 \
    libnspr4 \
    libdbus-1-3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libx11-6 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libxcb1 \
    libxkbcommon0 \
    libpango-1.0-0 \
    libcairo2 \
    libasound2t64 \
    libatspi2.0-0 \
 && rm -rf /var/lib/apt/lists/* &&"
fi
 maven_build() {

	# If docker creates this directory it does it as the wrong user, so create it first
	# These are on the host so they can be re-used between builds
	mkdir -p "$MAVEN_BUILD_DATA/.m2"
	mkdir -p "$MAVEN_BUILD_DATA/.npm"
	mkdir -p "$MAVEN_BUILD_DATA/.config"
	mkdir -p "$MAVEN_BUILD_DATA/.cache"

	echo "run maven build docker"
	# Now build the code
	docker run --rm --name maven \
		-e "MAVEN_CONFIG=/tmp/.m2" \
	    -v "${SAKAI_SOURCE_DIRECTORY_LOCATION}:/tmp/sakai" \
	    -v "${MAVEN_BUILD_DATA}/.m2:/tmp/.m2" \
	    -v "${MAVEN_BUILD_DATA}/.npm:/.npm" \
	    -v "${MAVEN_BUILD_DATA}/.config:/.config" \
	    -v "${MAVEN_BUILD_DATA}/.cache:/.cache" \
	    -v "${SAKAI_DEPLOY_TARGET}:/tmp/deploy/${TOMCAT_EXTRACTED_BASENAME}" \
	    --cap-add=SYS_ADMIN \
	    -w /tmp/sakai ${MAVEN_CONTAINER} \
		/bin/bash -c "${SUDO_USER_CMD}${SAKAI_26_BUILD_DEPENDENCIES}${SUDO_WHOAMI}${SET_JAVA_HOME} mvn -e -T ${THREADS} -B ${UPDATES} clean install sakai:deploy -Dmaven.test.skip=${SKIP_TEST} -Djava.awt.headless=true -Dmaven.tomcat.home=/tmp/deploy/${TOMCAT_EXTRACTED_BASENAME} -Dsakai.cleanup=true -Duser.home=/tmp/ ${MVN_EXTRA_OPTS}"
}




container_check_and_rm "maven"
maven_build



if [[ $?  -eq 0 ]]; then
	mkdir -p "sakai/build/${TOMCAT_EXTRACTED_BASENAME}/sakai"
	if [[ ${SAKAI_VERSION} == ${SAKAI_MASTER} ]]; then
		echo "copying sakai properties for master"
		cp "sakai/properties/sakai.properties.master" "sakai/build/${TOMCAT_EXTRACTED_BASENAME}/sakai/sakai.properties"
	elif [[ ${SAKAI_VERSION} == ${SAKAI_25} ]]; then
		echo "copying sakai properties for sakai 25"
		cp "sakai/properties/sakai.properties.25" "sakai/build/${TOMCAT_EXTRACTED_BASENAME}/sakai/sakai.properties"
	fi
	
	
	echo "copying tomcat files"
	cp ./tomcat/copy/* "./sakai/build/${TOMCAT_EXTRACTED_BASENAME}"

	echo "building sakai finished"
	return 0
else
	echo "building sakai failed"
	return 1
fi


