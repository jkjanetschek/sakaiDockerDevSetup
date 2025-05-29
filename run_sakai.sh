

cd $(dirname "${0}") > /dev/null
BASEDIR=$(pwd -L)
cd - > /dev/null


# # redundant, shoeld be available here via source command  in main.sh
APACHE_NAME=$1        
APACHE_NAME=$1$2
STARTUP_OPTION=$3
DATABASE_CONTAINER=$4 
TOMCAT_CONTAINER=$5  

DATABASE_SERVER="mariadb"
DATABASE="sakaidatabase"
DATABASE_USER="sakaiuser"
DATABASE_PASSWORD="sakaipassword"
MYSQL_ROOT_PASSWORD="password"

SQL_DATADIR=${BASEDIR}"/mariaDbData/mysql"
CATALINA_BASE=${BASEDIR}"/sakai/build/"${APACHE_NAME}

TIMEZONE="Europe/Vienna"
JPDA_ADDRESS="*:38000"



container_check_and_rm() {
    local CONTAINER_NAME=$1
    local CONTAINER_ID=$(docker inspect --format="{{.Id}}" ${CONTAINER_NAME} 2> /dev/null)
    if [[ "${CONTAINER_ID}" ]]; then
        echo "${CONTAINER_NAME} exists, removing previous instance"
    	docker stop ${CONTAINER_NAME} 2> /dev/null && docker rm ${CONTAINER_NAME} 2> /dev/null
    fi
}

network_check_and_create() {
	# NETWORK_NAME set in main.sh
	local NETWORK_ID=$(docker network inspect --format="{{.Id}}"  ${NETWORK_NAME} 2> /dev/null)
	# -z checks if variable is emtpy
	echo "check if network ${NETWORK_NAME}"
 	if [[ -z "${NETWORK_ID}" ]]; then
 		echo "network ${NETWORK_NAME} does not exist"
		docker network create ${NETWORK_NAME}
 	fi
}

container_startup_check() {
    sleep 3
    local CONTAINER_NAME=$1
    local CONTAINER_ID=$(docker inspect --format="{{.State.Running}}" ${CONTAINER_NAME} 2> /dev/null)
    if [[ "${CONTAINER_ID}" ]]; then
        echo "${CONTAINER_NAME} is running"
        return 0
    else
        echo "${CONTAINER_NAME} not running"
        return 1
    fi
}


############################################################################
#   DATABASE                                                               #
############################################################################

## sql files at localation /scripts:/docker-entrypoint-initdb.d  will be executed by docker image
start_database() {
    container_check_and_rm "mariadb"
    echo "run new instance of container mariadb"
    docker run --rm --name mariadb \
    -v "${SQL_DATADIR}:/var/lib/mysql" \
    -v "${BASEDIR}/mariaDbData/scripts:/docker-entrypoint-initdb.d" \
    -e MARIADB_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD} \
    -e MARIADB_DATABASE=${DATABASE} \
    -e MARIADB_USER=${DATABASE_USER} \
    -e MARIADB_PASSWORD=${DATABASE_PASSWORD} \
    --network=sakai-network \
    -p 3306:3306 \
    -d ${DATABASE_CONTAINER} \
    --character-set-server=utf8mb4 \
    --collation-server=utf8mb4_unicode_ci > /dev/null
}





############################################################################
#   PROXY                                                                  #
############################################################################
# https://github.com/esplo/docker-local-ssl-termination-proxy
# nginx and tomcat need to be configured for X-Forwarded headers
start_proxy() {
    # Startup the https proxy first
    container_check_and_rm "docker-local-ssl-termination-proxy"
    docker run -d --name="docker-local-ssl-termination-proxy" \
	-e "PORT=8080" \
    --network=sakai-network \
	--add-host=host.docker.internal:host-gateway \
	-p 443:443 \
	--rm ${PROXY_CONTAINER}
}





############################################################################
#   TOMCAT                                                                 #
############################################################################

JDK17_OPTS="--add-opens=java.base/jdk.internal.access=ALL-UNNAMED \
        --add-opens=java.base/jdk.internal.misc=ALL-UNNAMED \
        --add-opens=java.base/sun.nio.ch=ALL-UNNAMED \
        --add-opens=java.base/sun.util.calendar=ALL-UNNAMED \
        --add-opens=java.management/com.sun.jmx.mbeanserver=ALL-UNNAMED \
        --add-opens=jdk.internal.jvmstat/sun.jvmstat.monitor=ALL-UNNAMED \
        --add-opens=java.base/sun.reflect.generics.reflectiveObjects=ALL-UNNAMED \
        --add-opens=jdk.management/com.sun.management.internal=ALL-UNNAMED \
        --add-opens=java.base/java.io=ALL-UNNAMED \
        --add-opens=java.base/java.nio=ALL-UNNAMED \
        --add-opens=java.base/java.net=ALL-UNNAMED \
        --add-opens=java.base/java.util=ALL-UNNAMED \
        --add-opens=java.base/java.util.concurrent=ALL-UNNAMED \
        --add-opens=java.base/java.util.concurrent.locks=ALL-UNNAMED \
        --add-opens=java.base/java.util.concurrent.atomic=ALL-UNNAMED \
        --add-opens=java.base/java.lang=ALL-UNNAMED \
        --add-opens=java.base/java.lang.invoke=ALL-UNNAMED \
        --add-opens=java.base/java.math=ALL-UNNAMED \
        --add-opens=java.sql/java.sql=ALL-UNNAMED \
        --add-opens=java.base/java.lang.reflect=ALL-UNNAMED \
        --add-opens=java.base/java.time=ALL-UNNAMED \
        --add-opens=java.base/java.text=ALL-UNNAMED \
        --add-opens=java.management/sun.management=ALL-UNNAMED \
        --add-opens=java.desktop/java.awt.font=ALL-UNNAMED \
        --add-opens=java.desktop/javax.swing.tree=ALL-UNNAMED"
JDK_GC="-XX:+UseG1GC -XX:+UseStringDeduplication -XX:ParallelGCThreads=8 -XX:ConcGCThreads=2 -XX:+UseContainerSupport -XX:+UnlockExperimentalVMOptions"
# -XX:+UseContainerSupport -XX:+UnlockExperimentalVMOptions--> Important for container support!
JAVA_OPTS="-server -Xms512m -Xmx2g -Djava.awt.headless=true -XX:+UseCompressedOops -Dhttp.agent=Sakai \
			-Dorg.apache.jasper.compiler.Parser.STRICT_QUOTE_ESCAPING=false -Dsakai.home=/tmp/${APACHE_NAME}/sakai \
			-Duser.timezone=${TIMEZONE} -Dsakai.cookieName=SAKAI2SESSIONID \
            -XX:+TieredCompilation -XX:TieredStopAtLevel=1 \
            -Dcom.sun.management.jmxremote \
            -Dcom.sun.management.jmxremote.port=8089 -Dcom.sun.management.jmxremote.local.only=false \
            -Dcom.sun.management.jmxremote.rmi.port=8089 -Djava.rmi.server.hostname=193.171.234.98 \
            -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false \
            ${JDK17_OPTS} ${JDK_GC}"

 
# expose 8080 also for proxy image: docker-local-ssl-termination-proxy does only use host IP
start_tomcat() {
    container_check_and_rm "sakai-tomcat"
	docker run -d --name="sakai-tomcat" \
	    -p 8080:8080 -p 8089:8089 -p 8000:8000 -p 8025:8025 \
	    -e "CATALINA_BASE=/tmp/${APACHE_NAME}" \
	    -e "CATALINA_TMPDIR=/tmp" \
	    -e "JAVA_OPTS=${JAVA_OPTS}" \
	    -e "JPDA_ADDRESS=${JPDA_ADDRESS}" \
        -e "PDA_TRANSPORT=dt_socket" \
		-e "JPDA_SUSPEND=n" \
	    -v "${CATALINA_BASE}:/tmp/${APACHE_NAME}" \
	    --network=sakai-network \
        --add-host=host.docker.internal:host-gateway \
	    ${TOMCAT_CONTAINER} \
	    /tmp/${APACHE_NAME}/bin/catalina.sh ${STARTUP_OPTION}
}

############################################################################
############################################################################

network_check_and_create
start_database
container_startup_check mariadb
if [[ $? -eq 0 ]]; then
	start_proxy
	container_startup_check docker-local-ssl-termination-proxy
	if [[ $? -eq 0 ]]; then
	    start_tomcat
		echo "start tomcat"
	else
		echo "proxy startup failed"
	fi
else
    echo "database startup failed"
fi


