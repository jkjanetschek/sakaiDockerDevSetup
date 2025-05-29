# sakaiDockerSetup  Github Doku

central file to control setup: main.sh

folder structure: check if folders exist

    main.sh
    build_sakai.sh
    run_sakai.sh
    mavenBuildData
    mariaDbData
        mysql
        scripts
            e.g. sql get executed the first time the container starts up & mysql folder is emtpy
    sakai
        sakai --> Source code of sakai
        build  --> folder for build and packaged sakai
        properties
            sakai.properties.<sakai_Version. e.g master, 25> --> get copied to build location
    tomcat --> tar.gz files of tomcat releases
        copy
            catalina.properties --> get copied from sakai/build/properties
    

        
sql script in mariaDbData/scripts shoudl create database and user on startup --> if not create manually in container terminal


### IMPORTANT ####

run this from home of user, as user has more permissions there. If problem with folder permissions --> workaround set perm chmod -R 777 on mavenBuildData and sakai/sakai


If running on windows with Docker Desktop:
    install seperate wsl distro
    set WSL integration in docker desktop also for newly installed wsl distro
	run sudo usermod -aG docker $USER
	restart wsl




   
    

    

