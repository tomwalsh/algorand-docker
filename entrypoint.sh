#!/usr/bin/env bash
set -Eeo pipefail
/bin/mv /home/app/genesis.json /home/app/.algorand
chown -R app:app /home/app/.algorand
chmod 777 /home/app/.algorand
exec /bin/gosu app /bin/algod -l 0.0.0.0:8080