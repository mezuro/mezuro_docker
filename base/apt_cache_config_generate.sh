#!/bin/sh

APT_CONF_PROXY_FILE='/etc/apt/apt.conf.d/02proxy.conf'

if [ -z "${APT_CACHE_TCP_ADDR}" ] || [ -z "${APT_CACHE_TCP_PORT}"] \
   || ! ping -c 1 "${APT_CACHE_TCP_ADDR}";
then
	rm "${APT_CONF_PROXY_FILE}"
else
	cat > "${APT_CONF_PROXY_FILE}" <<EOF
Acquire {
	HTTP::proxy "http://${APT_CACHE_TCP_ADDR}:${APT_CACHE_TCP_PORT}";
	FTP::proxy "http://${APT_CACHE_TCP_ADDR}:${APT_CACHE_TCP_PORT}";
};
EOF