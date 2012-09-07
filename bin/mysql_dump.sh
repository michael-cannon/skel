#!/bin/bash

# Simple MySQL database dumper
#
# @author Michael Cannon, michael@typo3vagabond.com

# four args
if [ ! ${4} ]
then
	FUNCTION=`basename $0`
	echo "Usage: ${FUNCTION} host user password database"
	echo Simple MySQL database dumper
	exit
fi

DATE=`date +'%F'`
FILE="${4}.${DATE}.sql"

nice mysqldump \
	--host=${1} \
	--user=${2} \
	--password="${3}" \
	--opt \
	--quote-names \
	--skip-set-charset \
	--default-character-set=latin1 \
	"${4}" > ${FILE}

perl -pi -e "s#(CHARSET=)([^;]+)#\1utf8#g" ${FILE}
gzip ${FILE}

echo Database ${4} dumped and compressed to file ${FILE}.gz
