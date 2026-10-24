#!/bin/bash
set -euo pipefail
state=$(MYSQL_PWD="$MARIADB_ROOT_PASSWORD" mariadb -h 127.0.0.1 -u root -N -B -e "SHOW GLOBAL STATUS WHERE Variable_name IN ('wsrep_cluster_status','wsrep_local_state','wsrep_ready','wsrep_connected')")
grep -q $'wsrep_cluster_status\tPrimary' <<< "$state"
grep -q $'wsrep_local_state\t4' <<< "$state"
grep -q $'wsrep_ready\tON' <<< "$state"
grep -q $'wsrep_connected\tON' <<< "$state"
