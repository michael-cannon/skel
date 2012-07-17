#!/bin/sh

# Function helpers for pulling live websites to localhost
#
# Assumptions
# * Password-less access via SSH is possible to domain account
# * Using MacPorts or like and including vhosts via DIR_VHOST
# * ~/.ssh directory exists
# * Local websites in ~/Sites via SITES, best overridden via LOCAL_DIR_WWW
# * Web group is www via WWW_GROUP
# * Web user is USER via WWW_USER
# * MySQL is running on local and remote systems
#
# Create a script with the following '## ' prepends to use.
#
# Basic script
## DOMAIN_NAME="example.com"
## source ~/.skel/scripts/live2local.sh
## 
## l2l_site_typo3
## l2l_do_sync ${@}
#
#
# Advanced script
## DOMAIN_NAME="example.com"
##
## # optional settings
## DB_HOST="db.example.com"
## DB_LOCALHOST="localhost"
## DB_NAME="example_wp"
## DB_PW="1234qwer"
## DB_USER="example_wp"
## DOMAIN_BASE="example"
## DOMAIN_LOCALHOST="example.localhost"
## DOMAIN_USER="example"
## LOCAL_DB_MODS[1]="UPDATE wp_options SET option_value = '${HTTP_DOMAIN_LOCALHOST} WHERE option_value LIKE 'http://${DOMAIN_NAME}' ;"
## LOCAL_MODS[1]="perl -pi -e \"s#^(define\('COOKIE_DOMAIN', '${DOMAIN_NAME}'.*$)#// \1#g\" wp-config.php"
## SITES="Sites" # Used only in LOCAL_DIR_WWW
## LOCAL_DIR_WWW="/Users/michael/Sites/example"
## REMOTE_SERVER="user@dev.example.com"
## REMOTE_DIR_WWW="/var/www/dev.example.com"
## RSYNC_MODS="--include=fileadmin/MediaContent/ --exclude=**/fileadmin/MediaContent/**"
## TYPO3_VERSION="4.5.15"
## WWW_GROUP="www"
## WWW_USER="michael"
## USE_FTP="true"
##
## # load live2local function helpers
## source ~/.skel/scripts/live2local.sh
##
## # optional type of site
## [l2l_site_ilance|l2l_site_typo3|l2l_site_wordpress]
## # you can specify database or media only transfers if desired [db|media|setup|ssh]
## l2l_do_sync ${@}
## l2l_typo3_source ${TYPO3_VERSION} ${@}
#
# @author Michael Cannon <michael@typo3vagabond.com>

# TODO
# Enable interactive password handling for non-ssh keyed systems

# helps define parameters for the server being used
# could do some auto-detection, but not
if [[ -z ${HOST_SERVER} ]]
then
	APACHE_CMD=`which apachectl`
	DIR_VHOST="/opt/local/apache2/conf/vhosts"
else
	case "${HOST_SERVER}" in
		"42" )
		APACHE_CMD="`which service` apache2"
		APACHE_PORT="81"
		DIR_VHOST="/etc/apache2/sites-enabled"
		DIR_WWW="/var/www"
		DOMAIN_LOCALHOST_BASE='42.in2code.de'
		WWW_GROUP="www-data"
		# WWW_USER="www-data"
		;;

		* )
		echo "${HOST_SERVER} is not defined"
		exit
		;;
	esac
fi

if [[ -z ${APACHE_PORT} ]]
then
	APACHE_PORT="80"
fi

if [[ -z ${FILE_CONFIG_OVERWRITE_DENY} ]]
then
	FILE_CONFIG_OVERWRITE_DENY=
fi

if [[ -z ${BIN_MYSQL} ]]
then
	BIN_MYSQL=
else
	BIN_MYSQL="${BIN_MYSQL}/"
fi

if [[ -z ${DOMAIN_BASE} ]]
then
	# pull off unneeded www, then strip out country code and tld
	DOMAIN_BASE=`echo ${DOMAIN_NAME} | sed -e "s#^www\.##g" -e "s#\.[a-zA-Z]\{2\}\\$##g" -e "s#\.[a-zA-Z]\{2,4\}\\$##g"`
fi

if [[ -z ${DOMAIN_USER} ]]
then
	DOMAIN_USER=`echo ${DOMAIN_NAME} | sed -e "s#^www\.##g" | awk -F "." '{print $1}'`
fi

if [[ -z ${DOMAIN_LOCALHOST_BASE} ]]
then
	DOMAIN_LOCALHOST_BASE="localhost"
fi

if [[ -z ${DOMAIN_LOCALHOST} ]]
then
	DOMAIN_LOCALHOST="${DOMAIN_BASE}.${DOMAIN_LOCALHOST_BASE}"
fi

if [[ -z ${DIR_HOME} ]]
then
	DIR_HOME=${HOME}
fi

if [[ -z ${SITES} ]]
then
	SITES="Sites"
fi

if [[ -z ${LOCAL_DIR_WWW} && -z ${DIR_WWW} ]]
then
	LOCAL_DIR_WWW="${DIR_HOME}/${SITES}/${DOMAIN_BASE}"
elif [[ -z ${LOCAL_DIR_WWW} && -n ${DIR_WWW} ]]
then
	LOCAL_DIR_WWW="${DIR_WWW}/${DOMAIN_BASE}"
fi

if [[ -n ${LOCAL_DIR_USE_ROOT} ]]
then
	LOCAL_DIR_WWW="/${SITES}/${DOMAIN_BASE}"
fi

if [[ -z ${DB_HOST} ]]
then
	DB_HOST="localhost"
fi

if [[ -z ${DB_LOCALHOST} ]]
then
	DB_LOCALHOST="localhost"
fi

if [[ -z ${DB_LOCALHOST_IP} ]]
then
	DB_LOCALHOST_IP="127.0.0.1"
fi

if [[ -z ${DB_FULL_DUMP} ]]
then
	DB_FULL_DUMP=
fi

if [[ -z ${REMOTE_SERVER} ]]
then
	REMOTE_SERVER="${DOMAIN_USER}@${DOMAIN_NAME}"
fi

if [[ -z ${REMOTE_SSH} ]]
then
	REMOTE_SSH="ssh -t ${REMOTE_SERVER}"
fi

if [[ -z ${REMOTE_DIR_WWW} ]]
then
	REMOTE_DIR_WWW="/home/${DOMAIN_USER}/public_html"
fi

if [[ -z ${RSYNC_MODS} ]]
then
	RSYNC_MODS=
fi

if [[ -z ${WWW_GROUP} ]]
then
	WWW_GROUP="www"
fi

if [[ -z ${WWW_USER} ]]
then
	WWW_USER=${USER}
fi

if [[ -z ${DEV_GROUP} ]]
then
	DEV_GROUP="staff"
fi

if [[ -z ${DEV_USER} ]]
then
	DEV_USER=${WWW_USER}
fi

# Ex: --ignore-table='usr_web0_3'.cache_hash --ignore-table='usr_web0_3'.cache_imagesizes
if [[ -z ${DB_IGNORE} ]]
then
	DB_IGNORE=
fi

if [[ -z ${DB_UTF8_CONVERT} ]]
then
	DB_UTF8_CONVERT=
fi

# quick way to turn off create routines
if [[ -n ${NO_CREATE} ]]
then
	CONFIG_NO_CREATE=1
	DB_NO_CREATE=1
	HOSTS_NO_CREATE=1
	VHOST_NO_CREATE=1
fi

if [[ -z ${SKIP_PERMS} ]]
then
	SKIP_PERMS=
fi

# don't create config file
if [[ -z ${CONFIG_NO_CREATE} ]]
then
	CONFIG_NO_CREATE=
fi

# don't create database or user
if [[ -z ${DB_NO_CREATE} ]]
then
	DB_NO_CREATE=
fi

# don't create hosts entry
if [[ -z ${HOSTS_NO_CREATE} ]]
then
	HOSTS_NO_CREATE=
fi

# don't create vhost entry
if [[ -z ${VHOST_NO_CREATE} ]]
then
	VHOST_NO_CREATE=
fi

if [[ -z ${USE_FTP} ]]
then
	CMD_SCP=`which scp`
	CMD_RSYNC=`which rsync`
	CMD_FTP_PULL=
	CMD_FTP_PUSH=
else
	CMD_SCP=
	CMD_RSYNC=
	CMD_FTP_PULL=`which ncftpget`
	CMD_FTP_PUSH=`which ncftpput`
fi

FILE_CONFIG=
FILE_DB="${DOMAIN_BASE}.sql"
FILE_DB_GZ="${FILE_DB}.gz"
FTP_OPTIONS="-F -R -v -z"
FTP_REMOTE_SERVER="ftp://${REMOTE_SERVER}"
HTTP_PROTOCOL="http://"
HTTP_DOMAIN_LOCALHOST="${HTTP_PROTOCOL}${DOMAIN_LOCALHOST}"
HTTP_DOMAIN_NAME="${HTTP_PROTOCOL}${DOMAIN_NAME}"
IS_PUSH=
IS_TYPE=
LOCAL_BASE_DB_MODS_I=1
LOCAL_BASE_MODS_I=1
LOCAL_DIR_CONFIG="${DIR_HOME}/.ssh/l2l_config"
LOCAL_FILE_CONFIG="${LOCAL_DIR_CONFIG}/${DOMAIN_NAME}"
# REMOTE_FILE_DB="${REMOTE_DIR_WWW}/${FILE_DB}"
REMOTE_FILE_DB="~/${FILE_DB}"
# REMOTE_FILE_DB_GZ="${REMOTE_DIR_WWW}/${FILE_DB_GZ}"
REMOTE_FILE_DB_GZ="~/${FILE_DB_GZ}"
# RSYNC_OPTIONS="-Pahz --stats --delete-excluded"
RSYNC_OPTIONS="-Pahz -e ssh --stats"
RSYNC_SITE_INC_EXC=

WHICH_SUDO=`which sudo`
if [[ ${WHICH_SUDO} && "No *" != ${WHICH_SUDO} ]]
then
	BIN_SUDO=sudo
else
	BIN_SUDO=
fi


function l2l_get_sudo_pw() {
	if [[ -z ${SUDO_PW} ]]
	then
		echo "What is your sudo password? "
		read
		SUDO_PW="${REPLY}"
	fi

	return ${SUDO_PW}
}


function l2l_intro() {
	l2l_display "Begin ${HTTP_DOMAIN_NAME} to ${HTTP_DOMAIN_LOCALHOST} transfer"
}


function l2l_cd() {
	if [[ ! -d ${LOCAL_DIR_WWW} ]]
	then
		l2l_display "Directory not found: ${LOCAL_DIR_WWW}"

		l2l_access_create_document_root
	fi

	cd ${LOCAL_DIR_WWW}
}


function l2l_perms_prepare() {
	if [[ -n ${SKIP_PERMS} ]]
	then
		return
	fi

	l2l_display "Update local ${LOCAL_DIR_WWW} file permissions to allow file transfers"

	${BIN_SUDO} ~/bin/websitepermissions ${DEV_USER} ${DEV_GROUP} dev
}


function l2l_pull_remote_db() {
	l2l_display "Creating database dump on ${DOMAIN_NAME}"

	local charset=""
	if [[ -n ${DB_UTF8_CONVERT} ]]
	then
		local charset="--quote-names --skip-set-charset --default-character-set=latin1"
	fi

	local mysqldump="${BIN_MYSQL}mysqldump --host=${DB_HOST} --user=${DB_USER} --password='${DB_PW}' --opt ${charset}"

	if [[ -z ${DB_IGNORE} ]]
	then
		if [[ "typo3" == ${IS_TYPE} && -z ${DB_FULL_DUMP} ]]
		then
			# skip typical fat tables for TYPO3
			local ignore_tables="--ignore-table='${DB_NAME}'.cache_hash --ignore-table='${DB_NAME}'.cache_imagesizes --ignore-table='${DB_NAME}'.cache_md5params --ignore-table='${DB_NAME}'.cache_pages --ignore-table='${DB_NAME}'.cache_pagesection --ignore-table='${DB_NAME}'.cache_sys_dmail_stat --ignore-table='${DB_NAME}'.cache_treelist --ignore-table='${DB_NAME}'.cache_typo3temp_log --ignore-table='${DB_NAME}'.cachingframework_cache_hash --ignore-table='${DB_NAME}'.cachingframework_cache_hash_tags --ignore-table='${DB_NAME}'.cachingframework_cache_pages --ignore-table='${DB_NAME}'.cachingframework_cache_pages_tags --ignore-table='${DB_NAME}'.cachingframework_cache_pagesection --ignore-table='${DB_NAME}'.cachingframework_cache_pagesection_tags --ignore-table='${DB_NAME}'.cf_cache_hash --ignore-table='${DB_NAME}'.cf_cache_hash_tags --ignore-table='${DB_NAME}'.cf_cache_pages --ignore-table='${DB_NAME}'.cf_cache_pages_tags --ignore-table='${DB_NAME}'.cf_cache_pagesection --ignore-table='${DB_NAME}'.cf_cache_pagesection_tags --ignore-table='${DB_NAME}'.cf_extbase_object --ignore-table='${DB_NAME}'.cf_extbase_object_tags --ignore-table='${DB_NAME}'.cf_extbase_reflection --ignore-table='${DB_NAME}'.cf_extbase_reflection_tags --ignore-table='${DB_NAME}'.cf_workspaces_cache --ignore-table='${DB_NAME}'.cf_workspaces_cache_tags --ignore-table='${DB_NAME}'.index_debug --ignore-table='${DB_NAME}'.index_fulltext --ignore-table='${DB_NAME}'.index_grlist --ignore-table='${DB_NAME}'.index_phash --ignore-table='${DB_NAME}'.index_rel --ignore-table='${DB_NAME}'.index_section --ignore-table='${DB_NAME}'.index_stat_search --ignore-table='${DB_NAME}'.index_stat_word --ignore-table='${DB_NAME}'.index_words --ignore-table='${DB_NAME}'.sys_log --ignore-table='${DB_NAME}'.tx_realurl_chashcache --ignore-table='${DB_NAME}'.tx_realurl_errorlog"

			if [[ -z ${SHOW_COMMANDS} ]]
			then
				${REMOTE_SSH} "${mysqldump} --no-data '${DB_NAME}' > ${REMOTE_FILE_DB}"
				${REMOTE_SSH} "${mysqldump} ${ignore_tables} '${DB_NAME}' >> ${REMOTE_FILE_DB}"
			else
				echo "${mysqldump} --no-data '${DB_NAME}' > ${REMOTE_FILE_DB}"
				echo "${mysqldump} ${ignore_tables} '${DB_NAME}' >> ${REMOTE_FILE_DB}"
			fi
		else
			if [[ -z ${SHOW_COMMANDS} ]]
			then
				${REMOTE_SSH} "${mysqldump} '${DB_NAME}' > ${REMOTE_FILE_DB}"
			else
				echo "${mysqldump} '${DB_NAME}' > ${REMOTE_FILE_DB}"
			fi
		fi
	else
		if [[ -z ${SHOW_COMMANDS} ]]
		then
			${REMOTE_SSH} "${mysqldump} --no-data '${DB_NAME}' > ${REMOTE_FILE_DB}"
			${REMOTE_SSH} "${mysqldump} ${DB_IGNORE} '${DB_NAME}' >> ${REMOTE_FILE_DB}"
		else
			echo "${mysqldump} --no-data '${DB_NAME}' > ${REMOTE_FILE_DB}"
			echo "${mysqldump} ${DB_IGNORE} '${DB_NAME}' >> ${REMOTE_FILE_DB}"
		fi
	fi

	if [[ -z ${SHOW_COMMANDS} ]]
	then
		l2l_pull_remote_rm ${REMOTE_FILE_DB_GZ}
		${REMOTE_SSH} "gzip ${REMOTE_FILE_DB}"

		l2l_display "Pulling database dump to ${DOMAIN_LOCALHOST}"

		l2l_pull_remote_pull ${REMOTE_FILE_DB_GZ}
		l2l_pull_remote_rm ${REMOTE_FILE_DB_GZ}
	fi
}


function l2l_pull_remote_pull() {
	if [[ -z ${USE_FTP} ]]
	then
		${CMD_SCP} ${REMOTE_SERVER}:${1} .
	else
		${CMD_FTP_PULL} ${FTP_OPTIONS} ${FTP_REMOTE_SERVER}${1} .
	fi
}


function l2l_pull_remote_rm() {
	${REMOTE_SSH} "if [[ -e ${1} ]]; then rm ${1}; fi"
}


function l2l_local_import_db() {
	l2l_display "Updating local database"

	gunzip --force ${FILE_DB_GZ}

	if [[ -n ${DB_UTF8_CONVERT} ]]
	then
		l2l_mysql_convert_utf8 ${FILE_DB}
	fi

	l2l_mysql_local ${FILE_DB}
}


function l2l_mysql_convert_utf8() {
	local sql_file=${1}

	perl -pi -e "s#(CHARSET=)([^;]+)#\1utf8#g" ${sql_file}
	# perl -pi -e "s# CHARACTER SET [^ ]+##g" ${sql_file}
	# perl -pi -e "s#( COLLATE )[^ ]+#\1utf8#g" ${sql_file}
}


function l2l_mysql_local() {
	# useful for DB_* conflicts e.g. root
	if [[ -z ${DB_HOST_LOCAL} ]]
	then
		local db_host=${DB_LOCALHOST}
	else
		local db_host=${DB_HOST_LOCAL}
	fi

	if [[ -z ${DB_NAME_LOCAL} ]]
	then
		local db_name=${DB_NAME}
	else
		local db_name=${DB_NAME_LOCAL}
	fi

	if [[ -z ${DB_PW_LOCAL} ]]
	then
		local db_pw=${DB_PW}
	else
		local db_pw=${DB_PW_LOCAL}
	fi

	if [[ -z ${DB_USER_LOCAL} ]]
	then
		local db_user=${DB_USER}
	else
		local db_user=${DB_USER_LOCAL}
	fi

	local charset=""
	if [[ -n ${DB_UTF8_CONVERT} ]]
	then
		local charset="--default-character-set=utf8"
	fi

	if [[ -z ${SHOW_COMMANDS} ]]
	then
		mysql \
			--host=${db_host} \
			--user=${db_user} \
			--password="${db_pw}" \
			${chaset} \
			${db_name} < ${1}
	else
		echo "mysql --host=${db_host} --user=${db_user} --password=\"${db_pw}\" ${chaset} ${db_name} < ${1}"
	fi
}


function l2l_mysql_local_show() {
	# useful for DB_* conflicts e.g. root
	if [[ -z ${DB_HOST_LOCAL} ]]
	then
		local db_host=${DB_LOCALHOST}
	else
		local db_host=${DB_HOST_LOCAL}
	fi

	if [[ -z ${DB_NAME_LOCAL} ]]
	then
		local db_name=${DB_NAME}
	else
		local db_name=${DB_NAME_LOCAL}
	fi

	if [[ -z ${DB_PW_LOCAL} ]]
	then
		local db_pw=${DB_PW}
	else
		local db_pw=${DB_PW_LOCAL}
	fi

	if [[ -z ${DB_USER_LOCAL} ]]
	then
		local db_user=${DB_USER}
	else
		local db_user=${DB_USER_LOCAL}
	fi

	echo "mysql --host=${db_host} --user=${db_user} --password=\"${db_pw}\" ${db_name}"
}


function l2l_local_db_mods() {
	local LOCAL_DB_MODS_FILE="DELETE-ME-l2l_local_db_mods"
	local cmd=""

	# by system db mods
	local count=${#LOCAL_BASE_DB_MODS[@]}
	if [[ 0 < ${count} ]]
	then
		for (( i = 1; i <= ${count}; i++ ))
		do
			cmd=${LOCAL_BASE_DB_MODS[${i}]}
			if [[ -n ${cmd} ]]
			then
				echo "${cmd}" >> ${LOCAL_DB_MODS_FILE}
			fi
		done
	fi

	# user provided db mods
	count=${#LOCAL_DB_MODS[@]}
	if [[ 0 < ${count} ]]
	then
		for (( i = 1; i <= ${count}; i++ ))
		do
			cmd=${LOCAL_DB_MODS[${i}]}
			if [[ -n ${cmd} ]]
			then
				echo "${cmd}" >> ${LOCAL_DB_MODS_FILE}
			fi
		done
	fi

	if [[ -e ${LOCAL_DB_MODS_FILE} ]]
	then
		l2l_display "Perform local database modifications"

		l2l_mysql_local ${LOCAL_DB_MODS_FILE}

		echo
		cat ${LOCAL_DB_MODS_FILE}
		echo

		rm ${LOCAL_DB_MODS_FILE}
	else
		l2l_display "No local database modifications needed"
	fi
}


function l2l_push_remote_media() {
	l2l_display "Update ${DOMAIN} website media"

	if [[ -z ${USE_FTP} ]]
	then
		${CMD_RSYNC} ${RSYNC_OPTIONS} ${RSYNC_COMMON_INC_EXC} ${RSYNC_SITE_INC_EXC} ${RSYNC_MODS} * ${REMOTE_SERVER}:${REMOTE_DIR_WWW}/.
	else
		${CMD_FTP_PUSH} ${FTP_OPTIONS} * ${FTP_REMOTE_SERVER}${REMOTE_DIR_WWW}/.
	fi
}


function l2l_pull_remote_media() {
	l2l_display "Update local website media"

	if [[ -z ${USE_FTP} ]]
	then
		${CMD_RSYNC} ${RSYNC_OPTIONS} ${RSYNC_COMMON_INC_EXC} ${RSYNC_SITE_INC_EXC} ${RSYNC_MODS} ${REMOTE_SERVER}:${REMOTE_DIR_WWW}/* .
		${CMD_RSYNC} ${RSYNC_OPTIONS} ${RSYNC_COMMON_INC_EXC} ${RSYNC_SITE_INC_EXC} ${RSYNC_MODS} ${REMOTE_SERVER}:${REMOTE_DIR_WWW}/.htaccess* .
	else
		${CMD_FTP_PULL} ${FTP_OPTIONS} ${FTP_REMOTE_SERVER}${REMOTE_DIR_WWW}/* .
		${CMD_FTP_PULL} ${FTP_OPTIONS} ${FTP_REMOTE_SERVER}${REMOTE_DIR_WWW}/.htaccess* .
	fi
}


function l2l_local_media_mods() {
	local LOCAL_MODS_FILE="DELETE-ME-l2l_local_media_mods"

	if [[ -e ${LOCAL_MODS_FILE} ]]
	then
		rm ${LOCAL_MODS_FILE}
	fi

	# mods by system type
	local count=${#LOCAL_BASE_MODS[@]}
	if [[ 0 < ${count} ]]
	then
		for (( i = 1; i <= ${count}; i++ ))
		do
			local cmd=${LOCAL_BASE_MODS[${i}]}
			if [[ -n ${cmd} ]]
			then
				echo "${cmd}" >> ${LOCAL_MODS_FILE}
			fi
		done
	fi

	# user provided mods
	local count=${#LOCAL_MODS[@]}
	if [[ 0 < ${count} ]]
	then
		for (( i = 1; i <= ${count}; i++ ))
		do
			local cmd=${LOCAL_MODS[${i}]}
			if [[ -n ${cmd} ]]
			then
				echo "${cmd}" >> ${LOCAL_MODS_FILE}
			fi
		done
	fi

	if [[ -e ${LOCAL_MODS_FILE} ]]
	then
		l2l_display "Perform local website modifications"

		sh ${LOCAL_MODS_FILE}

		echo
		cat ${LOCAL_MODS_FILE}
		echo

		rm ${LOCAL_MODS_FILE}
	else
		l2l_display "No local website modifications needed"
	fi
}


function l2l_perms_restore() {
	if [[ -n ${SKIP_PERMS} ]]
	then
		return
	fi

	l2l_display "Update local website permissions to ${WWW_USER}:${WWW_GROUP}"

	${BIN_SUDO} ~/bin/websitepermissions ${WWW_USER} ${WWW_GROUP} dev

	if [[ ${DEV_USER} != ${WWW_USER} ]]
	then
		l2l_perms_developer
	fi
}


function l2l_perms_developer() {
	if [[ -n ${SKIP_PERMS} ]]
	then
		return
	fi

	${BIN_SUDO} find . \( -name ".svn" -o -name "CVS" \) -type d -exec chown -R ${DEV_USER} {} \; -exec chmod u+rw {} \;
}


function l2l_finish() {
	l2l_display "End ${HTTP_DOMAIN_NAME} to ${HTTP_DOMAIN_LOCALHOST} transfer"
}


function l2l_config_push() {
	l2l_display "Setup push configuration"

	IS_PUSH="true"

	# basic premise is to swap the remote and local values regarding domain
	# names and such some will be able to swap in a straight-forward manner,
	# but others like remote db or files might not be so easy

	# l2l_access_load

	# l2l_site_common
}


function l2l_do_sync() {
	case "${1}" in
		"rsync" )
		echo "${CMD_RSYNC} ${RSYNC_OPTIONS} ${RSYNC_COMMON_INC_EXC} ${RSYNC_SITE_INC_EXC} ${RSYNC_MODS} ${REMOTE_SERVER}:${REMOTE_DIR_WWW}/* ${LOCAL_DIR_WWW}/."
		echo
		exit
		;;

		"scp" )
		echo "scp ${REMOTE_SERVER}:${REMOTE_DIR_WWW}"
		echo
		exit
		;;

		"site" )
		echo "${HTTP_PROTOCOL}${DOMAIN_LOCALHOST}"
		echo
		exit
		;;

		"ssh" )
		echo "ssh ${REMOTE_SERVER}"
		echo
		exit
		;;

		"access" )
		cat ${LOCAL_FILE_CONFIG}
		exit
		;;

		"setup" )
		l2l_access_create
		exit
		;;
	esac

	l2l_cd

	# TODO allow short/long options to be passed in
	# let the working environment be configured and then do actual work
	if [[ -n ${2} ]]
	then
		case "${2}" in
			"push" )
			l2l_config_push
			;;
		esac
	fi
	
	l2l_access_load

	case "${1}" in
		"ftp" )
		if [[ -n ${2} ]]
		then
			${CMD_FTP_PULL} ${FTP_OPTIONS} ${FTP_REMOTE_SERVER}${REMOTE_DIR_WWW}/${2} .
		else
			echo "ftp ${FTP_REMOTE_SERVER}"
			echo
			echo "${CMD_FTP_PULL} ${FTP_OPTIONS} ${FTP_REMOTE_SERVER}${REMOTE_DIR_WWW}"
			echo
		fi
		;;

		"db" )
		if [[ -z ${2} ]]
		then
			l2l_intro
			l2l_site_common
			l2l_do_db
			l2l_finish
		elif [[ 'pull' = ${2} ]]
		then
			l2l_pull_remote_db
			exit
		elif [[ 'show' = ${2} ]]
		then
			l2l_mysql_local_show
			echo
			DB_NO_CREATE=1
			SHOW_COMMANDS=1
			l2l_access_create_database_user
			echo
			l2l_pull_remote_db
			echo
			exit
		elif [[ 'convert' = ${2} ]]
		then
			l2l_mysql_convert_utf8 ${3}
		else
			# load locally provided database
			l2l_mysql_local ${2}
		fi
		;;

		"media" )
		l2l_intro
		l2l_site_common
		l2l_do_media
		l2l_finish
		;;

		"remove" )
		cd ${DIR_HOME}
		l2l_remove_all
		;;

		* )
		l2l_intro
		l2l_site_common
		l2l_sudo_session
		l2l_do_db
		l2l_do_media
		l2l_finish
		;;

	esac
}


function l2l_sudo_session() {
	if [[ -n ${BIN_SUDO} ]]
	then
		# make sudo session available
		${BIN_SUDO} -v
	fi
}


function l2l_do_db() {
	# not possible to db export/import via FTP
	if [[ ! -z ${USE_FTP} ]]
	then
		return
	fi

	if [[ -z ${IS_PUSH} ]]
	then
		l2l_pull_remote_db
		l2l_local_import_db
		l2l_local_db_mods
	else
		# TODO push l2l_do_db
		# backup up remote db on remote, give date to file name, gzip afterward
		echo ''
	fi
}


function l2l_do_media() {
	if [[ -n ${FILE_CONFIG_OVERWRITE_DENY} ]]
	then
		l2l_display "Warning ${FILE_CONFIG} is excluded from update"
		RSYNC_SITE_INC_EXC="${RSYNC_SITE_INC_EXC} --exclude=${FILE_CONFIG}"
	fi

	if [[ -z ${IS_PUSH} ]]
	then
		l2l_sudo_session
		l2l_perms_prepare
		l2l_sudo_session
		l2l_pull_remote_media
		l2l_sudo_session
		l2l_local_media_mods
		l2l_sudo_session
		l2l_perms_restore
	else
		l2l_push_remote_media
	fi
}


function l2l_display() {
	echo ${1}
	echo
}


function l2l_site_common() {
	# TODO push search/replace to vars, then create mods based upon IS_PUSH
	LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="perl -pi -e 's/^(AddHandler fcgid-script .php)/# \1/g' .htaccess"
	LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="perl -pi -e 's#${DOMAIN_NAME}#${DOMAIN_LOCALHOST}#g' .htaccess"

	if [[ ${DB_LOCALHOST} != ${DB_HOST} ]]
	then
		LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="perl -pi -e 's#${DB_HOST}#${DB_LOCALHOST}#g' ${FILE_CONFIG}"
	fi

	RSYNC_COMMON_INC_EXC="--include=.htaccess* --include=temp/ --exclude=**/temp/** --include=tmp*/ --exclude=**/tmp*/** --include=zzz*/ --exclude=**/zzz*/** --exclude=error_log"
}


function l2l_access_load() {
	# access already provided from calling script
	if [[ -n ${DB_NAME} && -n ${DB_PW} && -n ${DB_USER} ]]
	then
		return
	fi

	if [[ ! -e ${LOCAL_FILE_CONFIG} ]]
	then
		l2l_access_create
	fi

	l2l_display "Loading access from ${LOCAL_FILE_CONFIG}"

	source ${LOCAL_FILE_CONFIG}

	if [[ ! -z ${USE_FTP} ]]
	then
		FTP_OPTIONS="${FTP_OPTIONS} -p ${FTP_PW}"
	fi

	return
}


function l2l_access_create() {
	l2l_access_create_document_root
	l2l_cd
	l2l_access_create_config_file
	l2l_access_create_database_user
	l2l_access_create_hosts
	l2l_access_create_vhost
	
	l2l_display "Setup http://${DOMAIN_LOCALHOST} completed"

	return
}


function l2l_remove_all() {
	l2l_remove_document_root
	l2l_remove_config_file
	l2l_remove_database_user
	l2l_remove_hosts
	l2l_remove_vhost
	
	l2l_display "Removal of http://${DOMAIN_LOCALHOST} completed"

	return
}


function l2l_remove_vhost() {
	if [[ -n ${VHOST_NO_CREATE} ]]
	then
		return
	fi

	l2l_display "Delete vhost entry"

	local vhost_conf="${DIR_VHOST}/${DOMAIN_LOCALHOST}.conf"

	if [[ -e "${vhost_conf}" ]]
	then
		${BIN_SUDO} rm ${vhost_conf}
		${BIN_SUDO} ${APACHE_CMD} restart
	fi
}


function l2l_remove_hosts() {
	if [[ -n ${HOSTS_NO_CREATE} ]]
	then
		return
	fi

	l2l_display "Delete hosts entry"

	local etc_hosts="/etc/hosts"
	local host_set=`grep -P "\b${DOMAIN_LOCALHOST}\b" ${etc_hosts}`

	if [[ -n ${host_set} ]]
	then
		${BIN_SUDO} sed "/${DOMAIN_LOCALHOST}/d" ${etc_hosts} > etc_hosts.tmp
		${BIN_SUDO} mv etc_hosts.tmp ${etc_hosts}
	fi
}


function l2l_remove_database_user() {
	l2l_display "Remove database & user"

	local LOCAL_DB_DROP_FILE="DELETE-ME-l2l_local_db_drop"

	if [[ -e ${LOCAL_DB_DROP_FILE} ]]
	then
		rm ${LOCAL_DB_DROP_FILE}
	fi

	echo "DROP DATABASE IF EXISTS \`${DB_NAME}\`;" >> ${LOCAL_DB_DROP_FILE}
	echo "DROP USER '${DB_USER}'@'localhost';" >> ${LOCAL_DB_DROP_FILE}
	echo "FLUSH PRIVILEGES;" >> ${LOCAL_DB_DROP_FILE}

	if [[ -z ${SHOW_COMMANDS} ]]
	then
		local db_local_pw=`l2l_get_mysql_pw`
		mysql \
			--host=localhost \
			--user=root \
			--password="${db_local_pw}" <  ${LOCAL_DB_DROP_FILE}
	fi

	if [[ -n ${IS_PUSH} ]]
	then
		l2l_display "Create database and user SQL for ${DOMAIN_NAME}"

		# local db_local_pw=`l2l_get_mysql_pw ${DOMAIN_BASE}`
		# l2l_pull_remote_push ${LOCAL_DB_DROP_FILE}
		# ${REMOTE_SSH} "mysql --host=localhost --user=root --password='${db_local_pw}' < ${LOCAL_DB_DROP_FILE}"
		# l2l_pull_remote_rm ${LOCAL_DB_DROP_FILE}

		echo
		echo
		cat ${LOCAL_DB_DROP_FILE}
		echo
		echo
	fi

	echo
	cat ${LOCAL_DB_DROP_FILE}
	echo

	rm ${LOCAL_DB_DROP_FILE}
}


function l2l_remove_config_file() {
	l2l_display "Remove config file"

	if [[ -e ${LOCAL_FILE_CONFIG} ]]
	then
		rm ${LOCAL_FILE_CONFIG}*
	fi
}


function l2l_remove_document_root() {
	if [[ -d ${LOCAL_DIR_WWW} ]]
	then
		l2l_display "Remove DocumentRoot"

		rm -rf ${LOCAL_DIR_WWW}
	fi
}


function l2l_access_create_document_root() {
	if [[ ! -d ${LOCAL_DIR_WWW} ]]
	then
		l2l_display "Create DocumentRoot"

		mkdir -p "${LOCAL_DIR_WWW}"
		chmod 775 ${LOCAL_DIR_WWW}
		chmod ug+s ${LOCAL_DIR_WWW}
	fi
}


function l2l_access_create_config_file() {
	if [[ -n ${CONFIG_NO_CREATE} ]]
	then
		l2l_access_load
		return
	fi

	l2l_display "Create config file"

	if [[ ! -e ${LOCAL_DIR_CONFIG} ]]
	then
		mkdir ${LOCAL_DIR_CONFIG}
	fi

	if [[ -e ${LOCAL_FILE_CONFIG} ]]
	then
		local DATE=`date +'%F'`
		local TIME=`date +'%T'`
		local EXT="${DATE}_${TIME}"
		mv ${LOCAL_FILE_CONFIG} ${LOCAL_FILE_CONFIG}.${EXT}
	fi

	touch ${LOCAL_FILE_CONFIG}
	chmod 600 ${LOCAL_FILE_CONFIG}

	if [[ -z ${IS_PUSH} && -n ${FILE_CONFIG} && ! -e ${FILE_CONFIG} && "mkvhost" != ${IS_TYPE} ]]
	then
		local dir_name=`dirname ${FILE_CONFIG}`

		if [[ ! -d ${dir_name} ]]
		then
			mkdir -p "${dir_name}"
		fi

		if [[ -z ${USE_FTP} ]]
		then
			${CMD_SCP} ${REMOTE_SERVER}:${REMOTE_DIR_WWW}/${FILE_CONFIG} ${FILE_CONFIG}
		else
			echo "What is the FTP password? "
			read
			echo "FTP_PW=\"${REPLY}\"" >> ${LOCAL_FILE_CONFIG}
			FTP_OPTIONS="${FTP_OPTIONS} -p ${REPLY}"

			${CMD_FTP_PULL} ${FTP_OPTIONS} ${FTP_REMOTE_SERVER}${REMOTE_DIR_WWW}/${FILE_CONFIG} ${FILE_CONFIG}

			if [[ -n ${dir_name} ]]
			then
				local file_name=`basename ${FILE_CONFIG}`
				mv ${file_name} ${dir_name}
			fi
		fi
	fi

	if [[ -e ${FILE_CONFIG} && -n ${IS_TYPE} ]]
	then
		case "${IS_TYPE}" in
			"typo3" )
			l2l_get_config_typo3
			;;

			"wohin" )
			l2l_get_config_wohin
			;;

			"ilance" )
			l2l_get_config_ilance
			;;
			
			"oscommerce" )
			l2l_get_config_oscommerce
			;;

			"xtcommerce" )
			l2l_get_config_xtcommerce
			;;

			"wordpress" )
			l2l_get_config_wordpress
			;;
		esac
	elif [[ "mkvhost" == ${IS_TYPE} ]]
	then
		DB_HOST=${DB_LOCALHOST}
		DB_NAME=${DOMAIN_BASE}
		DB_PW=${DOMAIN_BASE}
		DB_USER=${DOMAIN_BASE}
	else
		echo "What is the database hostname?"
		read
		DB_HOST=${REPLY}

		echo "What is the database name?"
		read
		DB_NAME=${REPLY}

		echo "What is the database username?"
		read
		DB_USER=${REPLY}

		echo "What is the database password?"
		read
		DB_PW=${REPLY}
	fi

	echo "DB_HOST=\"${DB_HOST}\"" >> ${LOCAL_FILE_CONFIG}
	echo "DB_NAME=\"${DB_NAME}\"" >> ${LOCAL_FILE_CONFIG}
	echo "DB_PW=\"${DB_PW}\"" >> ${LOCAL_FILE_CONFIG}
	echo "DB_USER=\"${DB_USER}\"" >> ${LOCAL_FILE_CONFIG}
}


function l2l_access_create_database_user() {
	l2l_display "Create database user"

	local LOCAL_DB_CREATE_FILE="DELETE-ME-l2l_local_db_create"

	if [[ -e ${LOCAL_DB_CREATE_FILE} ]]
	then
		rm ${LOCAL_DB_CREATE_FILE}
	fi

	if [[ -z ${DB_HOST_LOCAL} ]]
	then
		local db_host=${DB_HOST}
	else
		local db_host=${DB_HOST_LOCAL}
	fi

	if [[ -z ${DB_NAME_LOCAL} ]]
	then
		local db_name=${DB_NAME}
	else
		local db_name=${DB_NAME_LOCAL}
	fi

	if [[ -z ${DB_PW_LOCAL} ]]
	then
		local db_pw=${DB_PW}
	else
		local db_pw=${DB_PW_LOCAL}
	fi

	if [[ -z ${DB_USER_LOCAL} ]]
	then
		local db_user=${DB_USER}
	else
		local db_user=${DB_USER_LOCAL}
	fi

	echo "CREATE DATABASE IF NOT EXISTS \`${db_name}\` DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;" >> ${LOCAL_DB_CREATE_FILE}
	echo "CREATE USER '${db_user}'@'localhost' IDENTIFIED BY '${db_pw}';" >> ${LOCAL_DB_CREATE_FILE}
	echo "GRANT USAGE ON *.* TO '${db_user}'@'localhost' IDENTIFIED BY '${db_pw}';" >> ${LOCAL_DB_CREATE_FILE}
	echo "GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO '${db_user}'@'localhost';" >> ${LOCAL_DB_CREATE_FILE}
	echo "FLUSH PRIVILEGES;" >> ${LOCAL_DB_CREATE_FILE}

	if [[ -z ${DB_NO_CREATE} ]]
	then
		local db_local_pw=`l2l_get_mysql_pw`
		mysql \
			--host=localhost \
			--user=root \
			--password="${db_local_pw}" <  ${LOCAL_DB_CREATE_FILE}
	fi

	if [[ -n ${IS_PUSH} ]]
	then
		l2l_display "Create database and user SQL for ${DOMAIN_NAME}"

		# local db_local_pw=`l2l_get_mysql_pw ${DOMAIN_BASE}`
		# l2l_pull_remote_push ${LOCAL_DB_CREATE_FILE}
		# ${REMOTE_SSH} "mysql --host=localhost --user=root --password='${db_local_pw}' < ${LOCAL_DB_CREATE_FILE}"
		# l2l_pull_remote_rm ${LOCAL_DB_CREATE_FILE}

		echo
		echo
		cat ${LOCAL_DB_CREATE_FILE}
		echo
		echo
	fi

	echo
	cat ${LOCAL_DB_CREATE_FILE}
	echo

	rm ${LOCAL_DB_CREATE_FILE}
}


function l2l_pull_remote_push() {
	if [[ -z ${USE_FTP} ]]
	then
		${CMD_SCP} ${1} ${REMOTE_SERVER}:~/.
	else
		${CMD_FTP_PUSH} ${FTP_OPTIONS} ${1} ${FTP_REMOTE_SERVER}
	fi
}


function l2l_access_create_hosts() {
	if [[ -n ${HOSTS_NO_CREATE} ]]
	then
		return
	fi

	l2l_display "Create hosts entry"

	local etc_hosts="/etc/hosts"
	local host_set=`grep -P "\b${DOMAIN_LOCALHOST}\b" ${etc_hosts}`

	if [[ -z ${host_set} ]]
	then
		echo "sudo"
		${BIN_SUDO} chmod a+w ${etc_hosts}
		echo "" >> ${etc_hosts}
		echo "127.0.0.1 ${DOMAIN_LOCALHOST}" >> ${etc_hosts}
		echo "127.0.0.1 www.${DOMAIN_LOCALHOST}" >> ${etc_hosts}
		${BIN_SUDO} chmod go-w ${etc_hosts}
	fi
}


function l2l_access_create_vhost() {
	if [[ -n ${VHOST_NO_CREATE} ]]
	then
		return
	fi

	l2l_display "Create vhost entry"

	if [[ ! -d "${DIR_VHOST}" ]]
	then
		mkdir -p "${DIR_VHOST}"
		chmod 755 "${DIR_VHOST}"
	fi

	# No show in list as that's from a plist
	# of which we're not editing for now
	local vhost_conf="${DIR_VHOST}/${DOMAIN_LOCALHOST}.conf"

	# confirm not already done
	if [[ ! -e "${vhost_conf}" ]]
	then
		${BIN_SUDO} touch ${vhost_conf}
		${BIN_SUDO} chown ${USER} ${vhost_conf}

		echo "<VirtualHost *:${APACHE_PORT}>" >> "${vhost_conf}"
		echo "	ServerName ${DOMAIN_LOCALHOST}" >> "${vhost_conf}"
		echo "	DocumentRoot \"${LOCAL_DIR_WWW}\"" >> "${vhost_conf}"
		echo "	ServerAlias www.${DOMAIN_LOCALHOST}" >> "${vhost_conf}"
		echo "" >> "${vhost_conf}"
		echo "	<Directory \"${LOCAL_DIR_WWW}\">" >> "${vhost_conf}"
		echo "		Options Includes FollowSymLinks" >> "${vhost_conf}"
		echo "		AllowOverride All" >> "${vhost_conf}"
		echo "		Order allow,deny" >> "${vhost_conf}"
		echo "		Allow from all" >> "${vhost_conf}"
		echo "	</Directory>" >> "${vhost_conf}"
		echo "</VirtualHost>" >> "${vhost_conf}"

		${BIN_SUDO} ${APACHE_CMD} restart
	fi
}


function l2l_get_mysql_pw() {
	if [[ -z ${1} ]]
	then
		local db_pw_file="${DIR_HOME}/.ssh/l2l_config/mysql"
		local db_host="localhost"
	else
		local db_pw_file="${DIR_HOME}/.ssh/l2l_config/mysql.${1}"
		local db_host="${DOMAIN_BASE}"
	fi

	if [[ ! -e ${db_pw_file} ]]
	then
		echo "What is ${db_host}'s MySQL root password? "
		read
		echo "${REPLY}" >> ${db_pw_file}

		# TODO test MySQL root
	fi

	local db_pw=`cat ${db_pw_file}`

	echo ${db_pw}
}


function l2l_get_config_ilance {
	DB_HOST=`grep -P "\bDB_SERVER\b" ${FILE_CONFIG}`
	DB_HOST=`echo ${DB_HOST} | sed -e "s#');.*##g" -e "s#^.*, '##g"`

	DB_NAME=`grep -P "\bDB_DATABASE\b" ${FILE_CONFIG}`
	DB_NAME=`echo ${DB_NAME} | sed -e "s#');.*##g" -e "s#^.*, '##g"`

	DB_USER=`grep -P "\bDB_SERVER_USERNAME\b" ${FILE_CONFIG}`
	DB_USER=`echo ${DB_USER} | sed -e "s#');.*##g" -e "s#^.*, '##g"`

	DB_PW=`grep -P "\bDB_SERVER_PASSWORD\b" ${FILE_CONFIG}`
	DB_PW=`echo ${DB_PW} | sed -e "s#');.*##g" -e "s#^.*, '##g"`
	DB_PW=`echo ${DB_PW} | sed -e 's#(#\\\(#g' -e 's#)#\\\)#g'`

	return
}


function l2l_site_ilance() {
	IS_TYPE="ilance"
	FILE_CONFIG="functions/connect.php"

	# file mods
	LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="perl -pi -e 's#${DOMAIN_NAME}#${DOMAIN_LOCALHOST}#g' functions/config.php"
	LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="perl -pi -e 's#${REMOTE_DIR_WWW}#${LOCAL_DIR_WWW}#g' functions/config.php"

	# db mods
	# LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]=""

	# rsync mods
	RSYNC_SITE_INC_EXC="--include=cache/ --exclude=**/cache/**"
}


function l2l_get_config_wordpress {
	DB_HOST=`grep -P "\bDB_HOST\b" ${FILE_CONFIG}`
	DB_HOST=`echo ${DB_HOST} | sed -e "s#');.*##g" -e "s#^.*, '##g"`

	DB_NAME=`grep -P "\bDB_NAME\b" ${FILE_CONFIG}`
	DB_NAME=`echo ${DB_NAME} | sed -e "s#');.*##g" -e "s#^.*, '##g"`

	DB_USER=`grep -P "\bDB_USER\b" ${FILE_CONFIG}`
	DB_USER=`echo ${DB_USER} | sed -e "s#');.*##g" -e "s#^.*, '##g"`

	DB_PW=`grep -P "\bDB_PASSWORD\b" ${FILE_CONFIG}`
	DB_PW=`echo ${DB_PW} | sed -e "s#');.*##g" -e "s#^.*, '##g"`
	DB_PW=`echo ${DB_PW} | sed -e 's#(#\\\(#g' -e 's#)#\\\)#g'`

	return
}


function l2l_site_wordpress() {
	IS_TYPE="wordpress"
	FILE_CONFIG="wp-config.php"
	WWW_USER=${WWW_GROUP}

	# file mods
	# need to disable this in wp-config.php, else no login
	LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="perl -pi -e \"s#^(define\(\s?'COOKIE_DOMAIN', '${DOMAIN_NAME}'.*$)#// \1#g\" wp-config.php"
	LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="perl -pi -e \"s#^(define\(\s?'WP_HOME'.*$)#// \1#g\" wp-config.php"
	LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="perl -pi -e \"s#^(define\(\s?'WP_SITEURL'.*$)#// \1#g\" wp-config.php"
    LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="echo 'Turn off auto-posting and caching like plugins'"
    LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="open ${HTTP_DOMAIN_LOCALHOST}/wp-admin/plugins.php?plugin_status=active"

	# db mods
	LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]="UPDATE wp_options SET option_value = '${HTTP_DOMAIN_LOCALHOST}' WHERE option_value LIKE '${HTTP_DOMAIN_NAME}';"

	LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]="UPDATE wp_options SET option_value = '${HTTP_DOMAIN_LOCALHOST}' WHERE option_value LIKE '${HTTP_DOMAIN_NAME}/';"

	LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]="UPDATE wp_posts SET post_content = REPLACE(post_content, '${HTTP_DOMAIN_NAME}', '${HTTP_DOMAIN_LOCALHOST}') ;"

	# rsync mods
	RSYNC_SITE_INC_EXC="--include=wp-content/cache/ --exclude=**/wp-content/cache/** --include=wp-content/w3tc/ --exclude=**/wp-content/w3tc/**"
}


function l2l_site_wordpress_multisite() {
	l2l_site_wordpress

	# file mods
	# need to disable this in wp-config.php, else no login
	LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="perl -pi -e \"s#^(define\( 'DOMAIN_CURRENT_SITE', ')${DOMAIN_NAME}('.*$)#\1${DOMAIN_LOCALHOST}\2#g\" wp-config.php"

	# db mods
	LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]="UPDATE wp_sitemeta SET meta_value = '${DB_LOCALHOST_IP}' WHERE meta_key LIKE 'dm_ipaddress';"

	LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]="UPDATE wp_sitemeta SET meta_value = '${HTTP_DOMAIN_LOCALHOST}/' WHERE meta_value LIKE '${HTTP_DOMAIN_NAME}/';"

	LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]="UPDATE wp_blogs SET domain = '${DOMAIN_LOCALHOST}' WHERE domain LIKE '${DOMAIN_NAME}';"

	LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]="UPDATE wp_site SET domain = '${DOMAIN_LOCALHOST}' WHERE domain LIKE '${DOMAIN_NAME}';"

	local domain_sets="domain = REPLACE(domain, '.de', '${DOMAIN_LOCALHOST_BASE}')
		, domain = REPLACE(domain, '.net', '${DOMAIN_LOCALHOST_BASE}')
		, domain = REPLACE(domain, '.org', '${DOMAIN_LOCALHOST_BASE}')
		, domain = REPLACE(domain, '.com', '${DOMAIN_LOCALHOST_BASE}')"
	local where="WHERE domain RLIKE '.(com|net|org|de)\\$'"

	LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]="UPDATE wp_blogs SET ${domain_sets} ${where};"

	LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]="UPDATE wp_domain_mapping SET ${domain_sets} ${where};"

	# rsync mods
	# RSYNC_SITE_INC_EXC="${RSYNC_SITE_INC_EXC}"
}


function l2l_get_config_typo3 {
	DB_HOST=`grep -P "\btypo_db_host\b" ${FILE_CONFIG}`
	DB_HOST=`echo ${DB_HOST} | sed -e "s#';.*##g" -e "s#^.*'##g"`

	DB_NAME=`grep -P "\btypo_db\b" ${FILE_CONFIG}`
	DB_NAME=`echo ${DB_NAME} | sed -e "s#';.*##g" -e "s#^.*'##g"`

	DB_USER=`grep -P "\btypo_db_username\b" ${FILE_CONFIG}`
	DB_USER=`echo ${DB_USER} | sed -e "s#';.*##g" -e "s#^.*'##g"`

	DB_PW=`grep -P "\btypo_db_password\b" ${FILE_CONFIG}`
	DB_PW=`echo ${DB_PW} | sed -e "s#';.*##g" -e "s#^.*'##g"`
	DB_PW=`echo ${DB_PW} | sed -e 's#(#\\\(#g' -e 's#)#\\\)#g'`

	return
}


function l2l_site_typo3() {
	IS_TYPE="typo3"
	FILE_CONFIG="typo3conf/localconf.php"

	# file mods
	# LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="perl -pi -e \"s#^(define\('COOKIE_DOMAIN', '${DOMAIN_NAME}'.*$)#// \1#g\" wp-config.php"

	# db mods
	# LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]=""
	LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]="UPDATE sys_domain SET hidden = 1 WHERE domainName NOT LIKE '%.${DOMAIN_LOCALHOST_BASE}';"
	LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]="UPDATE sys_domain SET hidden = 0 WHERE domainName LIKE '%.${DOMAIN_LOCALHOST_BASE}';"

	# rsync mods
	RSYNC_SITE_INC_EXC="--include=typo3temp/ --exclude=**/typo3temp/** --include=_temp_/ --exclude=**/_temp_/** --exclude=typo3conf/temp_CACHED_*.php --exclude=typo3conf/deprecation_*.log"
}


function l2l_get_config_wohin {
	DB_HOST=`grep -P "\bdb_server\b" ${FILE_CONFIG}`
	DB_HOST=`echo ${DB_HOST} | sed -e 's#");.*##g' -e 's#^.*, "##g'`

	DB_NAME=`grep -P "\bdb_name\b" ${FILE_CONFIG}`
	DB_NAME=`echo ${DB_NAME} | sed -e 's#");.*##g' -e 's#^.*, "##g'`

	DB_USER=`grep -P "\bdb_user\b" ${FILE_CONFIG}`
	DB_USER=`echo ${DB_USER} | sed -e 's#");.*##g' -e 's#^.*, "##g'`

	DB_PW=`grep -P "\bdb_passwort\b" ${FILE_CONFIG}`
	DB_PW=`echo ${DB_PW} | sed -e 's#");.*##g' -e 's#^.*, "##g'`
	DB_PW=`echo ${DB_PW} | sed -e 's#(#\\\(#g' -e 's#)#\\\)#g'`

	return
}


function l2l_site_wohin() {
	IS_TYPE="wohin"
	FILE_CONFIG="diner2.inc.php"

	# file mods
	# LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="perl -pi -e \"s#^(define\('COOKIE_DOMAIN', '${DOMAIN_NAME}'.*$)#// \1#g\" wp-config.php"

	# db mods
	# LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]=""
	# LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]="UPDATE sys_domain SET hidden = 1 WHERE domainName NOT LIKE '%.${DOMAIN_LOCALHOST_BASE}';"
	# LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]="UPDATE sys_domain SET hidden = 0 WHERE domainName LIKE '%.${DOMAIN_LOCALHOST_BASE}';"

	# rsync mods
	# RSYNC_SITE_INC_EXC="--include=wohintemp/ --exclude=**/wohintemp/** --include=_temp_/ --exclude=**/_temp_/** --exclude=wohinconf/temp_CACHED_*.php --exclude=wohinconf/deprecation_*.log"
}


function l2l_get_config_oscommerce {
	DB_HOST=`grep -P "\bDB_SERVER\b" ${FILE_CONFIG}`
	DB_HOST=`echo ${DB_HOST} | sed -e "s#');.*##g" -e "s#^.*, '##g"`

	DB_NAME=`grep -P "\bDB_DATABASE\b" ${FILE_CONFIG}`
	DB_NAME=`echo ${DB_NAME} | sed -e "s#');.*##g" -e "s#^.*, '##g"`

	DB_USER=`grep -P "\bDB_SERVER_USERNAME\b" ${FILE_CONFIG}`
	DB_USER=`echo ${DB_USER} | sed -e "s#');.*##g" -e "s#^.*, '##g"`

	DB_PW=`grep -P "\bDB_SERVER_PASSWORD\b" ${FILE_CONFIG}`
	DB_PW=`echo ${DB_PW} | sed -e "s#');.*##g" -e "s#^.*, '##g"`
	DB_PW=`echo ${DB_PW} | sed -e 's#(#\\\(#g' -e 's#)#\\\)#g'`

	return
}


function l2l_site_oscommerce() {
	IS_TYPE="oscommerce"
	FILE_CONFIG="includes/configure.php"
	# WWW_USER=${WWW_GROUP}

	# file mods
	# need to disable this in wp-config.php, else no login
	LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="perl -pi -e \"s#${REMOTE_DIR_WWW}#${LOCAL_DIR_WWW}#g\" ${FILE_CONFIG} admin/${FILE_CONFIG}"
	LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="perl -pi -e \"s#(www\.)?${DOMAIN_NAME}#${DOMAIN_LOCALHOST}#g\" ${FILE_CONFIG} admin/${FILE_CONFIG}"
	LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="perl -pi -e \"s#https#http#g\" ${FILE_CONFIG} admin/${FILE_CONFIG}"
	LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="perl -pi -e \"s#'ENABLE_SSL_CATALOG', 'true'#'ENABLE_SSL_CATALOG', 'false'#g\" ${FILE_CONFIG} admin/${FILE_CONFIG}"

	# db mods
	LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]=""

	# rsync mods
	RSYNC_SITE_INC_EXC=""
}


function l2l_typo3_source() {
	local typo3_version=${1}
	local mode=${2}

	if [[ -z ${mode} || "media" == ${mode} ]]
	then
		cd ${LOCAL_DIR_WWW}
		t3upgrade.sh ${typo3_version}
		rm -rf zzz-typo3-backup-*
		l2l_perms_restore
	fi
}


function l2l_site_mkvhost() {
	IS_TYPE="mkvhost"
	FILE_CONFIG="skip"

	# file mods
	# LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="perl -pi -e 's#${DOMAIN_NAME}#${DOMAIN_LOCALHOST}#g' functions/config.php"
	# LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="perl -pi -e 's#${REMOTE_DIR_WWW}#${LOCAL_DIR_WWW}#g' functions/config.php"

	# db mods
	# LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]=""

	# rsync mods
	# RSYNC_SITE_INC_EXC="--include=cache/ --exclude=**/cache/**"
}


function l2l_site_xtcommerce() {
	IS_TYPE="xtcommerce"
	FILE_CONFIG="includes/configure.php"

	# file mods
	# LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="perl -pi -e \"s#^(define\('COOKIE_DOMAIN', '${DOMAIN_NAME}'.*$)#// \1#g\" wp-config.php"

	# db mods
	# LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]=""
	# LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]="UPDATE sys_domain SET hidden = 1 WHERE domainName NOT LIKE '%.${DOMAIN_LOCALHOST_BASE}';"
	# LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]="UPDATE sys_domain SET hidden = 0 WHERE domainName LIKE '%.${DOMAIN_LOCALHOST_BASE}';"

	# rsync mods
	# RSYNC_SITE_INC_EXC="--include=typo3temp/ --exclude=**/typo3temp/** --include=_temp_/ --exclude=**/_temp_/** --exclude=typo3conf/temp_CACHED_*.php --exclude=typo3conf/deprecation_*.log"
	if [[ -n ${FILE_CONFIG_OVERWRITE_DENY} ]]
	then
		RSYNC_SITE_INC_EXC="--exclude=${FILE_CONFIG}"
	fi
}


function l2l_get_config_xtcommerce {
	DB_HOST=`grep -P "\bDB_SERVER\b" ${FILE_CONFIG}`
	DB_HOST=`echo ${DB_HOST} | sed -e "s#');.*##g" -e "s#^.*, '##g"`

	DB_NAME=`grep -P "\bDB_DATABASE\b" ${FILE_CONFIG}`
	DB_NAME=`echo ${DB_NAME} | sed -e "s#');.*##g" -e "s#^.*, '##g"`

	DB_USER=`grep -P "\bDB_SERVER_USERNAME\b" ${FILE_CONFIG}`
	DB_USER=`echo ${DB_USER} | sed -e "s#');.*##g" -e "s#^.*, '##g"`

	DB_PW=`grep -P "\bDB_SERVER_PASSWORD\b" ${FILE_CONFIG}`
	DB_PW=`echo ${DB_PW} | sed -e "s#');.*##g" -e "s#^.*, '##g"`
	DB_PW=`echo ${DB_PW} | sed -e 's#(#\\\(#g' -e 's#)#\\\)#g'`

	return
}


function l2l_reset {
	unset DB_HOST
	unset DB_NAME
	unset DB_PW
	unset DB_USER
	unset DOMAIN_BASE
	unset DOMAIN_LOCALHOST
	unset DOMAIN_NAME
	unset LOCAL_DIR_WWW
	unset REMOTE_DIR_WWW
}