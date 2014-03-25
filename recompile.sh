#! /usr/bin/env bash

DIR=$(dirname $0)
pushd $DIR > /dev/null

if [[ ! -d node_modules ]]; then
	echo 'Installing compiler tools...'
	sleep 1
	npm install coffee-script
	npm install streamline
fi

echo 'Compiling...'

node_modules/streamline/bin/_coffee -c .

popd > /dev/null
