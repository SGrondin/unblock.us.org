#! /usr/bin/env bash

if [[ ! -d logs ]]; then
	mkdir logs
fi

if [[ ! -d node_modules ]]; then
	echo 'Installing dependencies...'
	sleep 1
	npm install
fi

exec &>> logs/watcher.txt
echo $(date) "Started"
until ./scripts/spawn.sh; do
	echo $(date) "Server crashed with exit code $?.  Respawning.." >&2
	sleep 1
done
