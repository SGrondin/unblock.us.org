#! /usr/bin/env bash

DIR=$(dirname $0)
pushd $DIR > /dev/null

if [[ ! -d node_modules ]]; then
	echo 'Installing dependencies...'
	sleep 1
	npm install
fi

echo 'Compiling...'

node_modules/streamline/bin/_coffee -c src/
mv src/*.js lib/

echo 'Done.'

popd > /dev/null
