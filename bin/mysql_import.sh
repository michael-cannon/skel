#!/bin/bash

# Simple MySQL database script loader
#
# @author Michael Cannon, mc@aihr.us

if [ ! ${4} ]
then
	FUNCTION=`basename $0`
	echo "Usage: ${FUNCTION} host user database sql-file"
	echo Simple MySQL database script loader
	exit
fi

nice mysql \
	--host=${1} \
	--user=${2} \
	--default-character-set=utf8 \
	"${3}" < ${4}
