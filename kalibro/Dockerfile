FROM ubuntu:12.04

ENV LANG C.UTF-8

RUN sed 's#archive\.ubuntu\.com/ubuntu#sft.if.usp.br/ubuntu#g' -i /etc/apt/sources.list

RUN DEBIAN_FRONTEND=noninteractive apt-get update

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
 --no-install-recommends --no-install-suggests \
 locales ca-certificates wget \
 git-core postgresql libpostgresql-jdbc-java tomcat6

ADD analizo.list /etc/apt/sources.list.d/analizo.list
ADD analizo_preferences /etc/apt/preferences.d/analizo
RUN wget -O - http://analizo.org/download/signing-key.asc | sudo apt-key add -

RUN DEBIAN_FRONTEND=noninteractive apt-get update

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
 --no-install-recommends --no-install-suggests \
 analizo

RUN mkdir -p /usr/share/tomcat6/.kalibro/{projects,logs}
RUN chown -R :tomcat6 /usr/share/tomcat6/.kalibro
RUN chmod 'g+s,a+r,ug+w,o-w' -R /usr/share/tomcat6/.kalibro

RUN chown :tomcat6 /var/lib/tomcat6/webapps
RUN chmod 664 -R /var/lib/tomcat6/webapps
RUN chmod +x /var/lib/tomcat6/webapps

RUN wget https://downloads.sourceforge.net/project/kalibrometrics/KalibroService.tar.gz -O - | \
 tar -xz -C "/var/lib/tomcat6/webapps" 

ADD kalibro.settings /usr/share/tomcat6/.kalibro/kalibro.settings
ADD kalibro_test.settings /usr/share/tomcat6/.kalibro/kalibro_test.settings

ADD create_db.sh /tmp/create_db.sh
RUN service postgresql start && sleep 2 && su postgres -c /tmp/create_db.sh
 
ADD start.sh /root/mezuro_start.sh
CMD /root/mezuro_start.sh
