#!/bin/sh
# yasm-libtool.sh - libtool/yasm bridge script

# Copyright (c) 2013 Alex Marsev

# This code is released under the libpng license.
# For conditions of distribution and use, see the disclaimer and license in png.h

COMMAND=""
while test $# -gt 0; do
	case "$1" in
		-felf*|-fwin*|-fmacho*) COMMAND="$COMMAND $1";;
		-f*) ;;
		*) COMMAND="$COMMAND $1";;
	esac
	shift
done
exec $COMMAND
