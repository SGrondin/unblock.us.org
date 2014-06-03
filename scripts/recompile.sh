#! /usr/bin/env bash

if [[ ! -d node_modules ]]; then
	echo 'Installing dependencies...'
	sleep 1
	npm install
fi

echo 'Compiling...'

node_modules/streamline/bin/_coffee -c src/
node_modules/streamline/bin/_coffee -c defs/
mv src/*.js lib/

echo 'Done.'
