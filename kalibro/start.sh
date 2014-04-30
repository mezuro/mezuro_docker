#!/bin/bash

set -e

service postgresql start || true
service tomcat6 start

while true; do
    PID=$(cat /var/run/tomcat6.pid)
    if [ -n "$PID" ] && [ -e /proc/$PID ]; then
        sleep 1
    else
        break
    fi
done
