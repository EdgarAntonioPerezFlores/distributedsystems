#!/bin/bash
set -e
install -o mongodb -g mongodb -m 400 /run/secrets/mongo-keyfile /tmp/replica.key
exec /usr/local/bin/docker-entrypoint.sh "$@"
