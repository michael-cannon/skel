#!/bin/sh

# Simple MySQL database dumper
#
# @author Michael Cannon, michael@peimic.com
# @version $Id: mysql_dump.sh,v 1.1.1.1 2010/04/14 09:05:44 peimic.comprock Exp $

# four args
if [ ! ${4} ]
then
	FUNCTION=`basename $0`
	echo "Usage: ${FUNCTION} host user password database"
	echo Simple MySQL database dumper
	exit 65
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
