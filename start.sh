#! /usr/bin/env bash

until ./spawn.sh; do
	echo $(date) "Server crashed with exit code $?.  Respawning.." >&2
	sleep 1
done

