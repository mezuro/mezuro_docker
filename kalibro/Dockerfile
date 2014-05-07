FROM ubuntu:14.04

MAINTAINER danielkza
ENV LANG en_US.UTF-8

RUN locale-gen en_US.UTF-8

RUN sed -i /etc/apt/sources.list \
 -e 's#archive\.ubuntu\.com/ubuntu#sft.if.usp.br/ubuntu#g' \
 -e 's/main$/main contrib/'

RUN DEBIAN_FRONTEND=noninteractive apt-get update

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
 apt-utils build-essential locales ca-certificates wget unzip \
 git-core postgresql

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
 --no-install-recommends --no-install-suggests \
 libpostgresql-jdbc-java tomcat6

ADD analizo.list /etc/apt/sources.list.d/analizo.list
ADD analizo.preferences /etc/apt/preferences.d/analizo
RUN wget -O - http://analizo.org/download/signing-key.asc | apt-key add -

RUN DEBIAN_FRONTEND=noninteractive apt-get update

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
 --no-install-recommends --no-install-suggests \
 analizo

RUN mkdir -p /usr/share/tomcat6/.kalibro/projects \ 
 /usr/share/tomcat6/.kalibro/logs \
 && chown -R :tomcat6 /usr/share/tomcat6/.kalibro \
 && chmod 'g+s,a+r,ug+w,o-w' -R /usr/share/tomcat6/.kalibro \
 && chown :tomcat6 /var/lib/tomcat6/webapps \
 && chmod 664 -R /var/lib/tomcat6/webapps \
 && chmod +x /var/lib/tomcat6/webapps

RUN cd /root/ && wget -q https://downloads.sourceforge.net/project/kalibrometrics/KalibroService.tar.gz
RUN tar xzf /root/KalibroService.tar.gz -C "/var/lib/tomcat6/webapps" \
 --strip-components 1 "KalibroService/KalibroService.war"

ADD kalibro.settings /usr/share/tomcat6/.kalibro/kalibro.settings
ADD kalibro_test.settings /usr/share/tomcat6/.kalibro/kalibro_test.settings

ADD create_db.sh /tmp/create_db.sh
RUN service postgresql start && sleep 2 && su postgres -c /tmp/create_db.sh
 
ADD start.sh /root/mezuro_start.sh
CMD /root/mezuro_start.sh
