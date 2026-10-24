#!/bin/sh

exec wget -q -T 1 -O /dev/null "http://127.0.0.1:$1/"
