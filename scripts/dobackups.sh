#!/bin/sh

DAYS_KEEP="7"
DIR_BACKUPS="/backups"
DIR_SH="/var/www/web0/files"
DIR_SOURCE="/var/www/web0/restore"
FILE_SOURCE="*.gz"
FTP_HOST="example.com"
FTP_PW="example1234"
FTP_USER="example"

echo "${FTP_PW}" | ${DIR_SH}/FtpDelete.pl --passive --days=${DAYS_KEEP} --verbose ftp://${FTP_USER}@${FTP_HOST}/

${DIR_SH}/simple_bu.sh

ncftpput -R -F -u ${FTP_USER} -p ${FTP_PW} ${FTP_HOST} ${DIR_BACKUPS}/ ${DIR_SOURCE}/${FILE_SOURCE} PASV
