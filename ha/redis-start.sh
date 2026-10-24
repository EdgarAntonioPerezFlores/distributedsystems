#!/bin/sh
set -eu
if [ ! -s /data/redis.conf ]; then
 cat > /data/redis.conf <<EOF
bind 0.0.0.0
protected-mode yes
port 6379
requirepass $REDIS_PASSWORD
masterauth $REDIS_PASSWORD
replica-announce-ip $NODE_IP
replica-announce-port 6379
save ""
appendonly no
maxmemory 128mb
maxmemory-policy allkeys-lru
dir /data
EOF
 if [ "$INITIAL_REPLICA" = 1 ]; then echo 'replicaof 172.28.0.21 6379' >> /data/redis.conf; fi
fi
chown redis:redis /data/redis.conf
exec /usr/local/bin/docker-entrypoint.sh redis-server /data/redis.conf
