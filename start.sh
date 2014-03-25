#! /usr/bin/env bash

DIR=$(dirname $0)
pushd $DIR > /dev/null

if [[ ! -d logs ]]; then
	mkdir logs
fi

if [[ ! -d node_modules ]]; then
	echo 'Installing dependencies...'
	sleep 1
	npm install bottleneck
	npm install coffee-script
	npm install streamline
fi

exec &>> logs/watcher.txt
echo $(date) "Started"
until ./spawn.sh; do
	echo $(date) "Server crashed with exit code $?.  Respawning.." >&2
	sleep 1
done

popd > /dev/null