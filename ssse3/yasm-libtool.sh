#!/bin/sh
# yasm-libtool.sh - libtool/yasm bridge script

# Copyright (c) 2013 Alex Marsev

# This code is released under the libpng license.
# For conditions of distribution and use, see the disclaimer and license in png.h

COMMAND=""
while test $# -gt 0; do
	test "$1" = "-fPIC" || COMMAND="$COMMAND $1"
	shift
done
exec $COMMAND
