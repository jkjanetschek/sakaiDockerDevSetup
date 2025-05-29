-- Creates a sakai database at first startup. this script is run only of mysql folder is emtpy
create database sakaidatabase25 default character set utf8mb4;
create database sakaidatabasemaster default character set utf8mb4;

grant all on `sakaidatabase25%`.* to sakaiuser@'localhost' identified by 'sakaipassword';
grant all on `sakaidatabase25%`.* to sakaiuser@'127.0.0.1' identified by 'sakaipassword';
grant all on `sakaidatabase25%`.* to sakaiuser@'%' identified by 'sakaipassword';



grant all on `sakaidatabasemaster%`.* to sakaiuser@'localhost' identified by 'sakaipassword';
grant all on `sakaidatabasemaster%`.* to sakaiuser@'127.0.0.1' identified by 'sakaipassword';
grant all on `sakaidatabasemaster%`.* to sakaiuser@'%' identified by 'sakaipassword';


flush privileges;
