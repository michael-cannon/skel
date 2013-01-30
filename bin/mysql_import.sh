#!/bin/bash

# Simple MySQL database script loader
#
# @author Michael Cannon, mc@aihr.us

# five args
if [ ! ${5} ]
then
	FUNCTION=`basename $0`
	echo "Usage: ${FUNCTION} host user password database sql-file"
	echo Simple MySQL database script loader
	exit
fi

nice mysql \
	--host=${1} \
	--user=${2} \
	--password="${3}" \
	--default-character-set=utf8 \
	"${4}" < ${5}
