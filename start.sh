#! /usr/bin/env bash

if [[ ! -d logs ]]; then
	mkdir logs
fi

if [[ ! -d node_modules ]]; then
	npm install bottleneck
	npm install streamline
fi

echo $(date) "Started"
until ./spawn.sh; do
	echo $(date) "Server crashed with exit code $?.  Respawning.." >&2
	sleep 1
done

