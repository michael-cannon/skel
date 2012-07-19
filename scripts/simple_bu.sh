#!/bin/bash
# simple backup and rotator script
#
# Original author unkown - Probably by Contigex support folks
#
# @author Michael Cannon <michael@typo3vagabond.com>

BACKUP_DIR="/backup/files"
CONF_FILE="/etc/httpd/vhosts.d/*"
DB_DIR="/var/lib/mysql/"
PW="$1"
ROTATOR="/backup/scripts/rotate_file.sh"


# check httpd conf for domains and docroots
DOCROOTS=`grep -r -h -e "^ *DocumentRoot.*" ${CONF_FILE}`

# backup website directories
for DOCROOT in ${DOCROOTS}
do
	if [ "DocumentRoot" == "${DOCROOT}" ]
	then
		continue
	fi

	SUB_DOMAIN=`echo ${DOCROOT} | awk -F "/" '{print $6}'`
	BASE_DOMAIN=`echo ${DOCROOT} | awk -F "/" '{print $5}'`
	DOMAIN="${SUB_DOMAIN}.${BASE_DOMAIN}"
	DOMAIN_FILE="${DOMAIN}.tgz"

	# echo "Domain ${DOMAIN}"
	# echo "DocumentRoot ${DOCROOT}"
	# echo "File ${DOMAIN_FILE}"

	${ROTATOR} ${BACKUP_DIR}/${DOMAIN_FILE}
	tar -czf ${BACKUP_DIR}/${DOMAIN_FILE} ${DOCROOT} \
		--exclude typo3temp/* \
		--exclude _temp_/*
done


# cycle through databases to create backup file for each
for DB in `find "${DB_DIR}" -type d \! -name mysql -exec basename {} \;`
do
	FILE="${BACKUP_DIR}/${DB}.sql"
	${ROTATOR} ${FILE}.gz
	mysqldump \
	 	--host=localhost \
	 	--user=root \
	 	--password=${PW} \
	 	--add-drop-table \
	 	--extended-insert \
	 	--opt \
	 	--databases ${DB} > ${FILE}
	gzip ${FILE}
	rm ${FILE}
done


# mysql skipped above as it's brought in twice
DB="mysql"
FILE="${BACKUP_DIR}/${DB}.sql"
${ROTATOR} ${FILE}.gz
mysqldump \
	--host=localhost \
	--user=root \
	--password=${PW} \
	--add-drop-table \
	--extended-insert \
	--opt \
	--databases ${DB} > ${FILE}
gzip ${FILE}
rm ${FILE}


# NFS data
# not rotated as it's too big of a file
## ${ROTATOR} ${BACKUP_DIR}/data.tgz
tar -czf ${BACKUP_DIR}/data.tgz /opt/nfs-share/data
