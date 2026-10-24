#!/bin/sh
set -eu
if [ ! -s /data/sentinel.conf ]; then
 cat > /data/sentinel.conf <<EOF
port 26379
bind 0.0.0.0
protected-mode yes
requirepass $REDIS_PASSWORD
dir /data
sentinel announce-ip $NODE_IP
sentinel announce-port 26379
sentinel monitor cachemaster 172.28.0.21 6379 2
sentinel auth-pass cachemaster $REDIS_PASSWORD
sentinel down-after-milliseconds cachemaster 5000
sentinel failover-timeout cachemaster 30000
sentinel parallel-syncs cachemaster 1
EOF
fi
chown redis:redis /data/sentinel.conf
exec /usr/local/bin/docker-entrypoint.sh redis-server /data/sentinel.conf --sentinel
