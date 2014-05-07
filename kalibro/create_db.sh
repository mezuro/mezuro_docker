#!/bin/bash

if ! psql -lqt | cut -d '|' -f 1 | grep -q kalibro; then
	psql --set ON_ERROR_STOP=1 <<'EOF'
CREATE ROLE kalibro
  LOGIN ENCRYPTED PASSWORD 'kalibro'
  VALID UNTIL 'infinity';
CREATE DATABASE kalibro
  WITH ENCODING='UTF8'
  OWNER=kalibro
  CONNECTION LIMIT=-1
  TEMPLATE=template0;
CREATE DATABASE kalibro_test
  WITH ENCODING='UTF8'
  OWNER=kalibro
  CONNECTION LIMIT=-1
  TEMPLATE=template0;
EOF
fi
