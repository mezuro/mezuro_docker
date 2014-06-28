#!/bin/sh

cd /var/lib/tomcat6/webapps/KalibroService/WEB-INF/lib
java -classpath '*' org.kalibro.ImportConfiguration "$1"