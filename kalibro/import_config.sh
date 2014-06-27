#!/bin/sh

java -classpath "/var/lib/tomcat6/webapps/KalibroService/WEB-INF/lib" \
 org.kalibro.ImportConfiguration "$1"