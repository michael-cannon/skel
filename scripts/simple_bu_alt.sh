#!/bin/bash
# stupid simple backup with 1-week remote rotation
#
# @author Michael Cannon <mc@aihr.us>


BACKUP_DIR="/var/www/web0/backup"
BACKUP_DIR="/var/www/web0/restore"
CONF_FILE="/etc/httpd/vhosts.d/*"
DAY=`date '+%a'`
DB_DIR="/var/lib/mysql/"
DB_PW="password"
DB_USER="web0"
DIR_BACKUPS="/backups"
FTP_HOST="example.com"
FTP_PW="password"
FTP_USER="user"
ROTATOR="/var/www/web0/files/rotate_file.sh"


function ftp_send() {
	FILE_GZ=`basename ${1}`
	FILE_GZ_DAY="${DAY}.${FILE_GZ}"

	cp ${1} ${FILE_GZ_DAY}

	ftp -nv ${FTP_HOST} << EOD
user ${FTP_USER} ${FTP_PW}
cd ${DIR_BACKUPS}
put ${FILE_GZ_DAY}
bye
EOD

	rm ${1}
}


## # check httpd conf for domains and docroots
## DOCROOTS=`grep -r -h -e "^ *DocumentRoot.*" ${CONF_FILE}`
## 
## # backup website directories
## for DOCROOT in ${DOCROOTS}
## do
## 	if [ "DocumentRoot" == "${DOCROOT}" ]
## 	then
## 		continue
## 	fi
## 
## 	SUB_DOMAIN=`echo ${DOCROOT} | awk -F "/" '{print $6}'`
## 	BASE_DOMAIN=`echo ${DOCROOT} | awk -F "/" '{print $5}'`
## 	DOMAIN="${SUB_DOMAIN}.${BASE_DOMAIN}"
## 	DOMAIN_FILE="${DOMAIN}.tgz"
## 
## 	# echo "Domain ${DOMAIN}"
## 	# echo "DocumentRoot ${DOCROOT}"
## 	# echo "File ${DOMAIN_FILE}"
## 
## 	${ROTATOR} ${BACKUP_DIR}/${DOMAIN_FILE}
## 	tar -czf ${BACKUP_DIR}/${DOMAIN_FILE} ${DOCROOT} \
## 		--exclude typo3temp/* \
## 		--exclude _temp_/*
## done


# cycle through databases to create backup file for each
for DB in `find "${DB_DIR}" -type d \! -name mysql \! -name confixx -exec basename {} \;`
do
	FILE="${BACKUP_DIR}/${DB}.sql"
	FILE_GZ="${FILE}.gz"

	# ${ROTATOR} ${FILE_GZ}
	if [[ -e ${FILE_GZ} ]]
	then
		mv ${FILE_GZ} ${FILE_GZ}.1
	fi

	mysqldump \
	 	--host=localhost \
	 	--user=${DB_USER} \
	 	--password=${DB_PW} \
	 	--add-drop-table \
	 	--extended-insert \
	 	--opt \
		--ignore-table=${DB}.cache_extensions \
		--ignore-table=${DB}.cache_hash \
		--ignore-table=${DB}.cache_imagesizes \
		--ignore-table=${DB}.cache_md5params \
		--ignore-table=${DB}.cache_pages \
		--ignore-table=${DB}.cache_pagesection \
		--ignore-table=${DB}.cache_sys_dmail_stat \
		--ignore-table=${DB}.cache_treelist \
		--ignore-table=${DB}.cache_typo3temp_log \
		--ignore-table=${DB}.cachingframework_cache_hash \
		--ignore-table=${DB}.cachingframework_cache_hash_tags \
		--ignore-table=${DB}.cachingframework_cache_pages \
		--ignore-table=${DB}.cachingframework_cache_pages_tags \
		--ignore-table=${DB}.cachingframework_cache_pagesection \
		--ignore-table=${DB}.cachingframework_cache_pagesection_tags \
		--ignore-table=${DB}.index_config \
		--ignore-table=${DB}.index_debug \
		--ignore-table=${DB}.index_fulltext \
		--ignore-table=${DB}.index_grlist \
		--ignore-table=${DB}.index_phash \
		--ignore-table=${DB}.index_rel \
		--ignore-table=${DB}.index_section \
		--ignore-table=${DB}.index_stat_search \
		--ignore-table=${DB}.index_stat_word \
		--ignore-table=${DB}.index_words \
		--ignore-table=${DB}.sys_log \
	 	--databases ${DB} > ${FILE}
	gzip ${FILE}

	if [[ -e ${FILE} ]]
	then
		echo "Failed: gzip ${FILE}"
		rm ${FILE}
	fi

	if [[ -e ${FILE_GZ} && -e ${FILE_GZ}.1 ]]
	then
		rm ${FILE_GZ}.1
	fi

	ftp_send ${FILE_GZ}


	# dump database structure only
	FILE="${BACKUP_DIR}/${DB}.no-data.sql"
	FILE_GZ="${FILE}.gz"

	if [[ -e ${FILE_GZ} ]]
	then
		mv ${FILE_GZ} ${FILE_GZ}.1
	fi

	mysqldump \
	 	--host=localhost \
	 	--user=${DB_USER} \
	 	--password=${DB_PW} \
	 	--add-drop-table \
		--no-data \
	 	--databases ${DB} > ${FILE}
	gzip ${FILE}

	if [[ -e ${FILE} ]]
	then
		echo "Failed: gzip ${FILE}"
		rm ${FILE}
	fi

	if [[ -e ${FILE_GZ} && -e ${FILE_GZ}.1 ]]
	then
		rm ${FILE_GZ}.1
	fi

	ftp_send ${FILE_GZ}
done


## # mysql skipped above as it's brought in twice
## DB="mysql"
## FILE="${BACKUP_DIR}/${DB}.sql"
## ${ROTATOR} ${FILE}.gz
## mysqldump \
## 	--host=localhost \
## 	--user=root \
## 	--password=${DB_PW} \
## 	--add-drop-table \
## 	--extended-insert \
## 	--opt \
## 	--databases ${DB} > ${FILE}
## gzip ${FILE}


# NFS data
# not rotated as it's too big of a file
## ${ROTATOR} ${BACKUP_DIR}/data.tgz
## tar -czf ${BACKUP_DIR}/data.tgz /opt/nfs-share/data
