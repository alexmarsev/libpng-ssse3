#!/bin/sh

COMMAND=""
while test $# -gt 0; do
	test "$1" = "-fPIC" || COMMAND="$COMMAND $1"
	shift
done
exec $COMMAND
