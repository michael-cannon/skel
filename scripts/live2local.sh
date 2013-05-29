#!/bin/bash

# Function helpers for migrating websites between remote servers or localhosts
#
# TODO
# * LIVE_MODE - typo3/wordpress don't clear domain settings
#
# @author Michael Cannon <mc@aihr.us>

# Assumptions
# * Password-less access via SSH is possible to domain account
# * Using MacPorts or like and including vhosts via DIR_VHOST
# * ~/.ssh directory exists
# * Local websites in ~/Sites via SITES, best overridden via LOCAL_DIR_WWW
# * Web group is www via WWW_GROUP
# * Web user is USER via WWW_USER
# * MySQL is running on local and remote systems
# * For FTP operations ncftp is installed
#
# Create a script with the following '## ' prepends to use.

# Basic script
## DOMAIN_NAME="example.com"
## source ~/.skel/scripts/live2local.sh
## 
## l2l_site_typo3
## l2l_do_sync ${@}


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
## TYPO3_VERSION="4.5.19"
## WWW_GROUP="www"
## WWW_USER="michael"
## # no ssh possible, do media pull via FTP
## USE_FTP=1
## # in case rsync not available, but ssh is, then try scp instead
## USE_SCP=1
##
## # load live2local function helpers
## source ~/.skel/scripts/live2local.sh
##
## # optional type of site
## [l2l_site_static|l2l_site_ilance|l2l_site_typo3|l2l_site_wordpress|l2l_site_phplist|l2l_site_openx]
## # you can specify database or media only transfers if desired [db|media|setup|ssh]
## l2l_do_sync ${@}
## l2l_typo3_source ${TYPO3_VERSION} ${@}


function l2l_do_sync() {
	l2l_settings_site

	# single line helpers
	case "${1}" in
		"access" )
		l2l_display ${LOCAL_FILE_CONFIG}
		cat ${LOCAL_FILE_CONFIG}
		echo
		exit
		;;

		"rsync" )
		l2l_display "${CMD_RSYNC} ${RSYNC_OPTIONS} ${RSYNC_COMMON_INC_EXC} ${RSYNC_SITE_INC_EXC} ${RSYNC_MODS} ${LOCAL_DIR_WWW}/* ${REMOTE_SERVER}:${REMOTE_DIR_WWW}/."
		exit
		;;

		"rsyncp" )
		l2l_display "${CMD_RSYNC} ${RSYNC_OPTIONS} ${RSYNC_COMMON_INC_EXC} ${RSYNC_SITE_INC_EXC} ${RSYNC_MODS} ${REMOTE_SERVER}:${REMOTE_DIR_WWW}/* ${LOCAL_DIR_WWW}/."
		exit
		;;

		"scp" )
		l2l_display "${CMD_SCP} ${SCP_OPTIONS} ${SCP_MODS} ${LOCAL_DIR_WWW}/* ${REMOTE_SERVER}:${REMOTE_DIR_WWW}/."
		exit
		;;

		"scpp" )
		l2l_display "${CMD_SCP} ${SCP_OPTIONS} ${SCP_MODS} ${REMOTE_SERVER}:${REMOTE_DIR_WWW}/* ${LOCAL_DIR_WWW}/."
		exit
		;;

		"setup" )
		l2l_access_create
		exit
		;;

		"site" )
		l2l_display "${LOCAL_DIR_WWW}"
		l2l_display "${HTTP_DOMAIN_LOCALHOST}:${APACHE_PORT}"
		exit
		;;

		"ssh" )
		l2l_display "ssh ${REMOTE_SERVER}"
		exit
		;;
	esac

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
	l2l_cd

	case "${1}" in
		"db" )
		if [[ "static" == ${IS_TYPE} ]]
		then
			l2l_display "Static website - No DB operations"
			return
		fi

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
			l2l_remove_database_user
			echo
			l2l_pull_remote_db
			echo
			exit
		elif [[ 'convert' = ${2} ]]
		then
			l2l_mysql_convert_utf8 ${3}
		elif [[ 'local' = ${2} ]]
		then
			l2l_pull_local_db
		else
			# load locally provided database
			l2l_mysql_local ${2}
		fi
		;;

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

		"media" )
		l2l_intro
		l2l_site_common
		l2l_do_media
		l2l_finish
		;;

		"perms" )
		if [[ -z ${2} ]]
		then
			l2l_cd
			l2l_perms_prepare
		else
			l2l_display "${BIN_SUDO} ~/bin/websitepermissions ${DEV_USER} ${DEV_GROUP} dev"
		fi
		exit
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


function l2l_run_once() {
	l2l_reset_type
	l2l_settings_server
	
	WHICH_SUDO=`which sudo`
	if [[ ${WHICH_SUDO} && "No *" != ${WHICH_SUDO} ]]
	then
		BIN_SUDO=sudo
	else
		BIN_SUDO=
	fi
}


function l2l_settings_server() {
	# helps define parameters for the server being used
	# could do some auto-detection, but not
	
	if [[ -z ${HOST_SERVER} ]]
	then
		# TODO auto-detect environment
		# cpanel - /scripts/restartsrv_httpd
		# assumes MacPorts for now
		# macports - /opt/local/apache2/bin/apachectl
	
		APACHE_CMD=`which apachectl`
		DIR_VHOST="/opt/local/apache2/conf/vhosts"
		DEV_GROUP="www"
		SITES="Sites"

		if [[ -z ${APACHE_PORT} ]]
		then
			APACHE_PORT=80
		fi
	else
		case "${HOST_SERVER}" in
			"42" )
			APACHE_CMD="`which service` apache2"
			APACHE_PORT=81
			DIR_VHOST="/etc/apache2/sites-enabled"
			DIR_WWW="/var/www"
			DOMAIN_LOCALHOST_BASE="42.in2code.de"
			WWW_GROUP="www-data"
			;;
	
			* )
			l2l_display "${HOST_SERVER} is not defined"
			exit
			;;
		esac
	fi
}
	
	
function l2l_settings_db() {
	if [[ -z ${BIN_MYSQL} ]]
	then
		BIN_MYSQL=
	else
		BIN_MYSQL="${BIN_MYSQL}/"
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
	
	# Ex: --ignore-table='usr_web0_3'.cache_hash --ignore-table='usr_web0_3'.cache_imagesizes
	if [[ -z ${DB_IGNORE} ]]
	then
		DB_IGNORE=
	fi
	
	if [[ -z ${DB_UTF8_CONVERT} ]]
	then
		DB_UTF8_CONVERT=
	fi

	FILE_DB="${DOMAIN_BASE}.sql"

	if [[ -z ${DB_HOST_LOCAL} ]]
	then
		DB_HOST_LOCAL=
	fi

	if [[ -z ${DB_NAME_LOCAL} ]]
	then
		DB_NAME_LOCAL=
	fi

	if [[ -z ${DB_PW_LOCAL} ]]
	then
		DB_PW_LOCAL=
	fi

	if [[ -z ${DB_USER_LOCAL} ]]
	then
		DB_USER_LOCAL=
	fi
}
	
	
function l2l_settings_db_local() {
	if [[ -z ${IS_LOCAL} ]]
	then
		return
	fi

	if [[ -z ${DB_HOST_LOCAL} ]]
	then
		DB_HOST_LOCAL="${DB_LOCALHOST}"
	fi

	if [[ -z ${DB_NAME_LOCAL} ]]
	then
		DB_NAME_LOCAL="${WWW_USER}_${IS_TYPE}"
	fi

	if [[ -z ${DB_PW_LOCAL} ]]
	then
		DB_PW_LOCAL="${WWW_USER}_${IS_TYPE}"
	fi

	if [[ -z ${DB_USER_LOCAL} ]]
	then
		DB_USER_LOCAL="${WWW_USER}_${IS_TYPE}"
	fi
}


function l2l_settings_no() {
	# quick way to turn off create routines
	if [[ -n ${NO_CREATE} ]]
	then
		CONFIG_NO_CREATE=1
		DB_NO_CREATE=1
		HOSTS_NO_CREATE=1
		VHOST_NO_CREATE=1
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
	
	if [[ -z ${FILE_CONFIG_NO_OVERWRITE} ]]
	then
		FILE_CONFIG_NO_OVERWRITE=
	fi
	
	if [[ -z ${SKIP_PERMS} ]]
	then
		SKIP_PERMS=
	fi
}


function l2l_settings_domain() {
	if [[ -z ${DOMAIN_NAME} ]]
	then
		l2l_display "DOMAIN_NAME is required. Ex: example.com"
		exit
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
	
	if [[ -z ${HTTP_PROTOCOL} ]]
	then
		HTTP_PROTOCOL="http://"
	fi

	if [[ -z ${HTTP_PROTOCOL_LOCAL} ]]
	then
		HTTP_PROTOCOL_LOCAL=${HTTP_PROTOCOL}
	fi

	HTTP_DOMAIN_LOCALHOST="${HTTP_PROTOCOL_LOCAL}${DOMAIN_LOCALHOST}"
	HTTP_DOMAIN_NAME="${HTTP_PROTOCOL}${DOMAIN_NAME}"
}


function l2l_settings_site() {
	if [[ -n ${SHOW_COMMANDS} ]]
	then
		l2l_display "SHOW_COMMANDS is active - no actual work performed"
	fi

	l2l_settings_domain
	l2l_settings_db
	l2l_settings_path
	l2l_settings_perm
	l2l_settings_remote
	l2l_settings_transfer
	l2l_settings_no

	if [[ -z ${FILE_CONFIG} ]]
	then
		FILE_CONFIG=
	fi
	
	if [[ -z ${IS_LIVE} ]]
	then
		IS_LIVE=
	fi
	
	if [[ -z ${IS_PUSH} ]]
	then
		IS_PUSH=
	fi

	if [[ -n ${IS_TYPE} ]]
	then
		LOCAL_FILE_CONFIG="${LOCAL_FILE_CONFIG}-${IS_TYPE}"
		FILE_DB="${DOMAIN_BASE}-${IS_TYPE}.sql"
	fi

	FILE_DB_GZ="${FILE_DB}.gz"
	REMOTE_FILE_DB="${REMOTE_DIR_WWW}/${FILE_DB}"
	REMOTE_FILE_DB_GZ="${REMOTE_DIR_WWW}/${FILE_DB_GZ}"
}


function l2l_settings_path() {
	if [[ -z ${DIR_HOME} ]]
	then
		DIR_HOME=${HOME}
	fi
	
	if [[ -z ${SITES} ]]
	then
		SITES="public_html"
	fi
	
	if [[ -z ${LOCAL_DIR_WWW} ]]
	then
		if [[ -n ${LOCAL_DIR_USE_ROOT} ]]
		then
			LOCAL_DIR_WWW="/${SITES}/${DOMAIN_BASE}"
		elif [[ -z ${DIR_WWW} ]]
		then
			LOCAL_DIR_WWW="${DIR_HOME}/${SITES}/${DOMAIN_BASE}"
		else
			LOCAL_DIR_WWW="${DIR_WWW}/${DOMAIN_BASE}"
		fi
	fi

	LOCAL_DIR_CONFIG="${DIR_HOME}/.ssh/l2l_config"
	LOCAL_FILE_CONFIG="${LOCAL_DIR_CONFIG}/${DOMAIN_NAME}"
}


function l2l_settings_remote() {
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
}

	
function l2l_settings_perm() {
	if [[ -z ${PERMS_MODE} ]]
	then
		PERMS_MODE="dev"
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
		DEV_GROUP=${WWW_GROUP}
	fi
	
	if [[ -z ${DEV_USER} ]]
	then
		DEV_USER=${WWW_USER}
	fi
}


function l2l_settings_transfer() {
	if [[ -z ${RSYNC_MODS} ]]
	then
		RSYNC_MODS=
	fi

	if [[ -z ${RSYNC_SITE_INC_EXC} ]]
	then
		RSYNC_SITE_INC_EXC=
	fi
	
	if [[ -z ${SCP_MODS} ]]
	then
		SCP_MODS=
	fi
	
	if [[ -z ${USE_FTP} ]]
	then
		CMD_FTP_PULL=
		CMD_FTP_PUSH=
		CMD_RSYNC=
		CMD_SCP=`which scp`
	
		if [[ -z ${USE_SCP} ]]
		then
			CMD_RSYNC=`which rsync`
		fi
	else
		CMD_FTP_PULL=`which ncftpget`
		CMD_FTP_PUSH=`which ncftpput`
		CMD_RSYNC=
		CMD_SCP=
	fi

	FTP_OPTIONS="-F -R -v -z"
	FTP_OPTIONS="-R -v -z"
	FTP_REMOTE_SERVER="ftp://${REMOTE_SERVER}"
	RSYNC_OPTIONS="-Pahz -e ssh --stats"
	SCP_OPTIONS="-r -p -C"
}


function l2l_reset_all() {
	unset APACHE_CMD
	unset APACHE_PORT
	unset BIN_MYSQL
	unset BIN_SUDO
	unset CMD_FTP_PULL
	unset CMD_FTP_PUSH
	unset CMD_RSYNC
	unset CMD_SCP
	unset CONFIG_NO_CREATE
	unset DB_FULL_DUMP
	unset DB_IGNORE
	unset DB_LOCALHOST
	unset DB_LOCALHOST_IP
	unset DB_NO_CREATE
	unset DB_UTF8_CONVERT
	unset DEV_GROUP
	unset DEV_USER
	unset DIR_HOME
	unset DIR_VHOST
	unset DIR_WWW
	unset DOMAIN_LOCALHOST_BASE
	unset DOMAIN_USER
	unset DO_LOCAL
	unset FILE_CONFIG
	unset FILE_CONFIG_NO_OVERWRITE
	unset FILE_DB
	unset FILE_DB_GZ
	unset FTP_OPTIONS
	unset FTP_REMOTE_SERVER
	unset HOSTS_NO_CREATE
	unset HOST_SERVER
	unset HTTP_DOMAIN_LOCALHOST
	unset HTTP_DOMAIN_NAME
	unset HTTP_PROTOCOL_LOCAL
	unset HTTP_PROTOCOL
	unset IS_PUSH
	unset IS_LOCAL
	unset LOCAL_DIR_CONFIG
	unset LOCAL_FILE_CONFIG
	unset PERMS_MODE
	unset REMOTE_FILE_DB
	unset REMOTE_FILE_DB_GZ
	unset REMOTE_SERVER
	unset REMOTE_SSH
	unset RSYNC_MODS
	unset RSYNC_OPTIONS
	unset RSYNC_SITE_INC_EXC
	unset SCP_MODS
	unset SCP_OPTIONS
	unset SITES
	unset SKIP_PERMS
	unset VHOST_NO_CREATE
	unset WHICH_SUDO
	unset WWW_GROUP
	unset WWW_USER

	l2l_reset
	l2l_run_once
}


function l2l_reset() {
	l2l_reset_app
	l2l_reset_domain
}


function l2l_reset_app() {
	l2l_reset_db
	l2l_reset_type
}


function l2l_reset_type() {
	unset IS_TYPE
	l2l_reset_local_base
	l2l_reset_local
}


function l2l_reset_local() {
	unset LOCAL_DB_MODS
	unset LOCAL_MODS
}


function l2l_reset_local_base() {
	LOCAL_BASE_DB_MODS_I=1
	LOCAL_BASE_MODS_I=1
	unset LOCAL_BASE_DB_MODS
	unset LOCAL_BASE_MODS
}


function l2l_reset_domain() {
	unset DOMAIN_BASE
	unset DOMAIN_LOCALHOST
	unset DOMAIN_NAME
	unset IS_LIVE
	unset LOCAL_DIR_WWW
	unset REMOTE_DIR_WWW
}


function l2l_reset_db() {
	unset DB_HOST
	unset DB_HOST_LOCAL
	unset DB_NAME
	unset DB_NAME_LOCAL
	unset DB_PW
	unset DB_PW_LOCAL
	unset DB_USER
	unset DB_USER_LOCAL
}


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


function l2l_pull_local_db() {
	l2l_display "Creating database dump on ${DOMAIN_LOCALHOST}"

	DO_LOCAL=1
	DB_HOST=${DB_LOCALHOST}
	REMOTE_FILE_DB="${LOCAL_DIR_WWW}/${DB_LOCALHOST}-${FILE_DB}"
	REMOTE_FILE_DB_GZ="${LOCAL_DIR_WWW}/${DB_LOCALHOST}-${FILE_DB_GZ}"

	l2l_pull_db
}


function l2l_pull_db() {
	local charset=
	if [[ -n ${DB_UTF8_CONVERT} ]]
	then
		local charset="--quote-names --skip-set-charset --default-character-set=latin1"
	fi

	local mysqldump="${BIN_MYSQL}mysqldump --host=${DB_HOST} --user=${DB_USER} --password='${DB_PW}' --opt ${charset}"

	if [[ -n ${DO_LOCAL} ]]
	then
		# FIXME need to replace ' with " in mysqldump 
		echo ""
	fi

	if [[ -z ${DB_IGNORE} ]]
	then
		if [[ "typo3" == ${IS_TYPE} && -z ${DB_FULL_DUMP} ]]
		then
			# skip typical fat tables for TYPO3
			local ignore_tables="--ignore-table='${DB_NAME}'.cache_hash --ignore-table='${DB_NAME}'.cache_imagesizes --ignore-table='${DB_NAME}'.cache_md5params --ignore-table='${DB_NAME}'.cache_pages --ignore-table='${DB_NAME}'.cache_pagesection --ignore-table='${DB_NAME}'.cache_sys_dmail_stat --ignore-table='${DB_NAME}'.cache_treelist --ignore-table='${DB_NAME}'.cache_typo3temp_log --ignore-table='${DB_NAME}'.cachingframework_cache_hash --ignore-table='${DB_NAME}'.cachingframework_cache_hash_tags --ignore-table='${DB_NAME}'.cachingframework_cache_pages --ignore-table='${DB_NAME}'.cachingframework_cache_pages_tags --ignore-table='${DB_NAME}'.cachingframework_cache_pagesection --ignore-table='${DB_NAME}'.cachingframework_cache_pagesection_tags --ignore-table='${DB_NAME}'.cf_cache_hash --ignore-table='${DB_NAME}'.cf_cache_hash_tags --ignore-table='${DB_NAME}'.cf_cache_pages --ignore-table='${DB_NAME}'.cf_cache_pages_tags --ignore-table='${DB_NAME}'.cf_cache_pagesection --ignore-table='${DB_NAME}'.cf_cache_pagesection_tags --ignore-table='${DB_NAME}'.cf_extbase_object --ignore-table='${DB_NAME}'.cf_extbase_object_tags --ignore-table='${DB_NAME}'.cf_extbase_reflection --ignore-table='${DB_NAME}'.cf_extbase_reflection_tags --ignore-table='${DB_NAME}'.cf_workspaces_cache --ignore-table='${DB_NAME}'.cf_workspaces_cache_tags --ignore-table='${DB_NAME}'.index_debug --ignore-table='${DB_NAME}'.index_fulltext --ignore-table='${DB_NAME}'.index_grlist --ignore-table='${DB_NAME}'.index_phash --ignore-table='${DB_NAME}'.index_rel --ignore-table='${DB_NAME}'.index_section --ignore-table='${DB_NAME}'.index_stat_search --ignore-table='${DB_NAME}'.index_stat_word --ignore-table='${DB_NAME}'.index_words --ignore-table='${DB_NAME}'.sys_log --ignore-table='${DB_NAME}'.tx_realurl_chashcache --ignore-table='${DB_NAME}'.tx_realurl_errorlog"

			if [[ -z ${SHOW_COMMANDS} ]]
			then
				if [[ -z ${DO_LOCAL} ]]
				then
					${REMOTE_SSH} "${mysqldump} --no-data '${DB_NAME}' > ${REMOTE_FILE_DB}"
					${REMOTE_SSH} "${mysqldump} ${ignore_tables} '${DB_NAME}' >> ${REMOTE_FILE_DB}"
				else
					${mysqldump} --no-data ${DB_NAME} > ${REMOTE_FILE_DB}
					${mysqldump} ${ignore_tables} ${DB_NAME} >> ${REMOTE_FILE_DB}
				fi
			else
				echo "${mysqldump} --no-data '${DB_NAME}' > ${REMOTE_FILE_DB}"
				echo "${mysqldump} ${ignore_tables} '${DB_NAME}' >> ${REMOTE_FILE_DB}"
			fi
		else
			if [[ -z ${SHOW_COMMANDS} ]]
			then
				if [[ -z ${DO_LOCAL} ]]
				then
					${REMOTE_SSH} "${mysqldump} '${DB_NAME}' > ${REMOTE_FILE_DB}"
				else
					# FIXME
					${BIN_MYSQL}mysqldump --host=${DB_HOST} --user=${DB_USER} --password="${DB_PW}" --opt ${charset} ${DB_NAME} > ${REMOTE_FILE_DB}
				fi
			else
				echo "${mysqldump} '${DB_NAME}' > ${REMOTE_FILE_DB}"
			fi
		fi
	else
		if [[ -z ${SHOW_COMMANDS} ]]
		then
			if [[ -z ${DO_LOCAL} ]]
			then
				${REMOTE_SSH} "${mysqldump} --no-data '${DB_NAME}' > ${REMOTE_FILE_DB}"
				${REMOTE_SSH} "${mysqldump} ${DB_IGNORE} '${DB_NAME}' >> ${REMOTE_FILE_DB}"
			else
				${mysqldump} --no-data ${DB_NAME} > ${REMOTE_FILE_DB}
				${mysqldump} ${DB_IGNORE} ${DB_NAME} >> ${REMOTE_FILE_DB}
			fi
		else
			echo "${mysqldump} --no-data '${DB_NAME}' > ${REMOTE_FILE_DB}"
			echo "${mysqldump} ${DB_IGNORE} '${DB_NAME}' >> ${REMOTE_FILE_DB}"
		fi
	fi
}


function l2l_pull_remote_db() {
	l2l_display "Creating database dump on ${DOMAIN_NAME}"
	l2l_pull_db

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
		${CMD_SCP} ${SCP_OPTIONS} ${REMOTE_SERVER}:${1} .
	else
		${CMD_FTP_PULL} ${FTP_OPTIONS} ${FTP_REMOTE_SERVER}${1} .
	fi
}


function l2l_pull_remote_rm() {
	${REMOTE_SSH} "if [[ -e ${1} ]]; then rm ${1}; fi"
}


function l2l_local_import_db() {
	if [[ "static" == ${IS_TYPE} ]]
	then
		return
	fi

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

	local charset=
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
	if [[ "static" == ${IS_TYPE} ]]
	then
		return
	fi

	local LOCAL_DB_MODS_FILE="DELETE-ME-l2l_local_db_mods"
	local cmd=

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

		echo
		cat ${LOCAL_DB_MODS_FILE}
		echo

		l2l_mysql_local ${LOCAL_DB_MODS_FILE}

		rm ${LOCAL_DB_MODS_FILE}
	else
		l2l_display "No local database modifications needed"
	fi
}


function l2l_push_remote_media() {
	l2l_display "Update ${DOMAIN} website media"

	if [[ -z ${USE_FTP} ]]
	then
		if [[ -z ${USE_SCP} ]]
		then
			${CMD_RSYNC} ${RSYNC_OPTIONS} ${RSYNC_COMMON_INC_EXC} ${RSYNC_SITE_INC_EXC} ${RSYNC_MODS} * ${REMOTE_SERVER}:${REMOTE_DIR_WWW}/.
		else
			${CMD_SCP} ${SCP_OPTIONS} ${SCP_MODS} * ${REMOTE_SERVER}:${REMOTE_DIR_WWW}/.
		fi
	else
		${CMD_FTP_PUSH} ${FTP_OPTIONS} * ${FTP_REMOTE_SERVER}${REMOTE_DIR_WWW}/.
	fi
}


function l2l_pull_remote_media() {
	l2l_display "Update local website media"

	if [[ -z ${USE_FTP} ]]
	then
		if [[ -z ${USE_SCP} ]]
		then
			${CMD_RSYNC} ${RSYNC_OPTIONS} ${RSYNC_COMMON_INC_EXC} ${RSYNC_SITE_INC_EXC} ${RSYNC_MODS} ${REMOTE_SERVER}:${REMOTE_DIR_WWW}/* .
			${CMD_RSYNC} ${RSYNC_OPTIONS} ${RSYNC_COMMON_INC_EXC} ${RSYNC_SITE_INC_EXC} ${RSYNC_MODS} ${REMOTE_SERVER}:${REMOTE_DIR_WWW}/.htaccess* .
		else
			${CMD_SCP} ${SCP_OPTIONS} ${SCP_MODS} ${REMOTE_SERVER}:${REMOTE_DIR_WWW}/* .
			${CMD_SCP} ${SCP_OPTIONS} ${SCP_MODS} ${REMOTE_SERVER}:${REMOTE_DIR_WWW}/.htaccess* .
		fi
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

		echo
		cat ${LOCAL_MODS_FILE}
		echo

		sh ${LOCAL_MODS_FILE}

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

	${BIN_SUDO} ~/bin/websitepermissions ${WWW_USER} ${WWW_GROUP} ${PERMS_MODE}

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

	${BIN_SUDO} find . \( -name ".git" -o -name ".svn" -o -name "CVS" \) -type d -exec chown -R ${DEV_USER} {} \; -exec chmod u+rw {} \;
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


function l2l_sudo_session() {
	if [[ -n ${BIN_SUDO} ]]
	then
		# make sudo session available
		${BIN_SUDO} -v
	fi
}


function l2l_do_db() {
	if [[ "static" == ${IS_TYPE} ]]
	then
		l2l_display "Static website - No DB operations"
		return
	fi

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
	if [[ -n ${FILE_CONFIG_NO_OVERWRITE} && "static" != ${IS_TYPE} ]]
 	then
		l2l_display "Warning '${FILE_CONFIG}' is excluded from update"
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
	echo
	echo ${1}
	echo
}


function l2l_site_common() {
	RSYNC_COMMON_INC_EXC="--include=.htaccess* --include=temp/ --exclude=**/temp/** --include=tmp*/ --exclude=**/tmp*/** --include=zzz*/ --exclude=**/zzz*/** --exclude=error_log"

	if [[ -n ${IS_LIVE} ]]
	then
		return
	fi

	# TODO push search/replace to vars, then create mods based upon IS_PUSH
	# LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="perl -pi -e 's/^(AddHandler fcgid-script .php)/# \1/g' .htaccess"
	LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="perl -pi -e 's#${DOMAIN_NAME}#${DOMAIN_LOCALHOST}#g' .htaccess"

	if [[ ${DB_LOCALHOST} != ${DB_HOST} && "static" != ${IS_TYPE} ]]
	then
		LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="perl -pi -e 's#${DB_HOST}#${DB_LOCALHOST}#g' ${FILE_CONFIG}"
	fi
}


function l2l_access_load() {
	# access already provided from calling script
	if [[ -n ${DB_NAME} && -n ${DB_PW} && -n ${DB_USER} ]]
	then
		l2l_settings_db_local

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

	l2l_settings_db_local

	return
}


function l2l_access_create() {
	l2l_access_create_document_root
	l2l_cd

	if [[ "static" != ${IS_TYPE} ]]
	then
		l2l_access_create_config_file
		l2l_settings_db_local
		l2l_access_create_config_file_local
		l2l_access_create_database_user
	fi

	l2l_access_create_hosts
	l2l_access_create_vhost
	
	l2l_display "Setup ${HTTP_DOMAIN_LOCALHOST}:${APACHE_PORT} completed"

	return
}


function l2l_remove_all() {
	l2l_settings_site
	l2l_remove_document_root
	l2l_remove_config_file

	if [[ "static" != ${IS_TYPE} ]]
	then
	 	l2l_remove_database_user
	fi

	l2l_remove_hosts
	l2l_remove_vhost
	
	l2l_display "Removal of ${HTTP_DOMAIN_LOCALHOST} completed"

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

	local LOCAL_DB_DROP_FILE="DELETE-ME-l2l_local_db_drop"

	if [[ -e ${LOCAL_DB_DROP_FILE} ]]
	then
		rm ${LOCAL_DB_DROP_FILE}
	fi

	echo "DROP DATABASE IF EXISTS \`${db_name}\`;" >> ${LOCAL_DB_DROP_FILE}
	echo "DROP USER '${db_user}'@'${db_host}';" >> ${LOCAL_DB_DROP_FILE}
	echo "FLUSH PRIVILEGES;" >> ${LOCAL_DB_DROP_FILE}

	if [[ -z ${SHOW_COMMANDS} ]]
	then
		local db_local_pw=`l2l_get_mysql_pw`
		mysql \
			--host=${db_host} \
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
	if [[ -d ${LOCAL_DIR_WWW} && -z ${VHOST_NO_CREATE} ]]
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


function l2l_access_create_config_file_local() {
	if [[ -z ${IS_LOCAL} || ! -e ${FILE_CONFIG} || -n ${FILE_CONFIG_NO_OVERWRITE} ]]
	then
		return
	fi
	
	l2l_display "Update ${FILE_CONFIG} with DB_*_LOCAL settings"

	# replace DB_* with DB_*_LOCAL entries in FILE_CONFIG
	if [[ -z ${SHOW_COMMANDS} ]]
	then
		perl -pi -e "s#${DB_HOST}#${DB_HOST_LOCAL}#g" ${FILE_CONFIG}
		perl -pi -e "s#${DB_NAME}#${DB_NAME_LOCAL}#g" ${FILE_CONFIG}
		perl -pi -e "s#${DB_USER}#${DB_USER_LOCAL}#g" ${FILE_CONFIG}
		perl -pi -e "s#${DB_PW}#${DB_PW_LOCAL}#g" ${FILE_CONFIG}
	else
		echo "perl -pi -e \"s#${DB_HOST}#${DB_HOST_LOCAL}#g\" ${FILE_CONFIG}"
		echo "perl -pi -e \"s#${DB_NAME}#${DB_NAME_LOCAL}#g\" ${FILE_CONFIG}"
		echo "perl -pi -e \"s#${DB_USER}#${DB_USER_LOCAL}#g\" ${FILE_CONFIG}"
		echo "perl -pi -e \"s#${DB_PW}#${DB_PW_LOCAL}#g\" ${FILE_CONFIG}"
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
			${CMD_SCP} ${SCP_OPTIONS} ${REMOTE_SERVER}:${REMOTE_DIR_WWW}/${FILE_CONFIG} ${FILE_CONFIG}
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
			"ilance" )
			l2l_get_config_ilance
			;;

			"oscommerce" )
			l2l_get_config_oscommerce
			;;

			"openx" )
			l2l_get_config_openx
			;;

			"phplist" )
			l2l_get_config_phplist
			;;
			
			"static" )
			l2l_get_config_static
			;;

			"typo3" )
			l2l_get_config_typo3
			;;

			"vbulletin" )
			l2l_get_config_vbulletin
			;;

			"wordpress" )
			l2l_get_config_wordpress
			;;

			"xtcommerce" )
			l2l_get_config_xtcommerce
			;;

			* )
			l2l_get_config_${IS_TYPE}
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

	echo "CREATE DATABASE IF NOT EXISTS \`${db_name}\` DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;" > ${LOCAL_DB_CREATE_FILE}
	echo "CREATE USER '${db_user}'@'${db_host}' IDENTIFIED BY '${db_pw}';" >> ${LOCAL_DB_CREATE_FILE}
	echo "GRANT USAGE ON *.* TO '${db_user}'@'${db_host}' IDENTIFIED BY '${db_pw}';" >> ${LOCAL_DB_CREATE_FILE}
	echo "GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO '${db_user}'@'${db_host}';" >> ${LOCAL_DB_CREATE_FILE}
	echo "FLUSH PRIVILEGES;" >> ${LOCAL_DB_CREATE_FILE}

	if [[ -z ${DB_NO_CREATE} ]]
	then
		local db_local_pw=`l2l_get_mysql_pw`
		mysql \
			--host=${db_host} \
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
		${CMD_SCP} ${SCP_OPTIONS} ${1} ${REMOTE_SERVER}:~/.
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
		local db_host="${DB_LOCALHOST}"
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


function l2l_get_config_ilance() {
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
	l2l_settings_domain

	IS_TYPE="ilance"
	FILE_CONFIG="functions/connect.php"

	# rsync mods
	RSYNC_SITE_INC_EXC="--include=cache/ --exclude=**/cache/**"

	if [[ -n ${IS_LIVE} ]]
	then
		return
	fi

	# file mods
	LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="perl -pi -e 's#${DOMAIN_NAME}#${DOMAIN_LOCALHOST}#g' functions/config.php"
	LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="perl -pi -e 's#${REMOTE_DIR_WWW}#${LOCAL_DIR_WWW}#g' functions/config.php"

	# db mods
	# LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]=
}


function l2l_get_config_typo3() {
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
	l2l_settings_domain

	IS_TYPE="typo3"
	FILE_CONFIG="typo3conf/localconf.php"

	# rsync mods
	RSYNC_SITE_INC_EXC="--include=typo3temp/ --exclude=**/typo3temp/** --include=_temp_/ --exclude=**/_temp_/** --exclude=typo3conf/temp_CACHED_*.php --exclude=typo3conf/deprecation_*.log"

	if [[ -n ${IS_LIVE} ]]
	then
		return
	fi

	# file mods
	LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="rm -f typo3conf/temp_CACHED_*.php"
	LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="rm -rf typo3temp/*"

	# db mods
	# LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]=
	LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]="UPDATE sys_domain SET hidden = 1 WHERE domainName NOT LIKE '%.${DOMAIN_LOCALHOST_BASE}';"
	LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]="UPDATE sys_domain SET hidden = 0 WHERE domainName LIKE '%.${DOMAIN_LOCALHOST_BASE}';"
}


function l2l_get_config_vbulletin() {
	DB_HOST=`grep -P "'\bservername\b'" ${FILE_CONFIG}`
	DB_HOST=`echo ${DB_HOST} | sed -e "s#';.*##g" -e "s#^.* '##g"`

	DB_NAME=`grep -P "'\bdbname\b'" ${FILE_CONFIG}`
	DB_NAME=`echo ${DB_NAME} | sed -e "s#';.*##g" -e "s#^.* '##g"`

	DB_USER=`grep -P "'\busername\b'" ${FILE_CONFIG}`
	DB_USER=`echo ${DB_USER} | sed -e "s#';.*##g" -e "s#^.* '##g"`

	DB_PW=`grep -P "'\bpassword\b'" ${FILE_CONFIG}`
	DB_PW=`echo ${DB_PW} | sed -e "s#';.*##g" -e "s#^.* '##g"`

	return
}


function l2l_site_vbulletin() {
	l2l_settings_domain

	IS_TYPE="vbulletin"

	if [[ -z ${FILE_CONFIG} ]]
	then
		FILE_CONFIG="includes/config.php"
	fi

	# rsync mods
	# RSYNC_SITE_INC_EXC="--include=vbulletintemp/ --exclude=**/vbulletintemp/** --include=_temp_/ --exclude=**/_temp_/** --exclude=vbulletinconf/temp_CACHED_*.php --exclude=vbulletinconf/deprecation_*.log"

	if [[ -n ${IS_LIVE} ]]
	then
		return
	fi

	# file mods
	# LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="rm -f vbulletinconf/temp_CACHED_*.php"
	# LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="rm -rf vbulletintemp/*"

	# db mods
	# LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]=
	# LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]="UPDATE sys_domain SET hidden = 1 WHERE domainName NOT LIKE '%.${DOMAIN_LOCALHOST_BASE}';"
	# LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]="UPDATE sys_domain SET hidden = 0 WHERE domainName LIKE '%.${DOMAIN_LOCALHOST_BASE}';"
}


function l2l_get_config_static() {
	return
}


function l2l_site_static() {
	l2l_settings_domain

	IS_TYPE="static"
	FILE_CONFIG=

	# rsync mods
	# RSYNC_SITE_INC_EXC=

	if [[ -n ${IS_LIVE} ]]
	then
		return
	fi

	# file mods
	# LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]=

	# db mods
	# LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]=
}


function l2l_get_config_openx() {
	DB_HOST=`grep -P -m 1 "\bhost\b" ${FILE_CONFIG}`
	DB_HOST=`echo ${DB_HOST} | sed -e 's#"\?$##g' -e 's#^.*="\?##g'`

	DB_NAME=`grep -P -m 1 "\bname\b" ${FILE_CONFIG}`
	DB_NAME=`echo ${DB_NAME} | sed -e 's#"\?$##g' -e 's#^.*="\?##g'`

	DB_USER=`grep -P -m 1 "\busername\b" ${FILE_CONFIG}`
	DB_USER=`echo ${DB_USER} | sed -e 's#"\?$##g' -e 's#^.*="\?##g'`

	DB_PW=`grep -P -m 1 "\bpassword\b" ${FILE_CONFIG}`
	DB_PW=`echo ${DB_PW} | sed -e 's#"\?$##g' -e 's#^.*="\?##g'`

	return
}


function l2l_site_openx() {
	l2l_settings_domain

	IS_TYPE="openx"
	if [[ -z ${FILE_CONFIG} ]]
	then
		FILE_CONFIG="openx/var/www.${DOMAIN_NAME}.conf.php"
	fi

	# rsync mods
	# RSYNC_SITE_INC_EXC=

	if [[ -n ${IS_LIVE} ]]
	then
		return
	fi

	# file mods
	# LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]=

	# db mods
	# LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]=
}


function l2l_get_config_phplist() {
	DB_HOST=`grep -P "\bdatabase_host\b" ${FILE_CONFIG}`
	DB_HOST=`echo ${DB_HOST} | sed -e 's#";.*##g' -e 's#^.*"##g'`

	DB_NAME=`grep -P "\bdatabase_name\b" ${FILE_CONFIG}`
	DB_NAME=`echo ${DB_NAME} | sed -e 's#";.*##g' -e 's#^.*"##g'`

	DB_USER=`grep -P "\bdatabase_user\b" ${FILE_CONFIG}`
	DB_USER=`echo ${DB_USER} | sed -e 's#";.*##g' -e 's#^.*"##g'`

	DB_PW=`grep -P "\bdatabase_password\b" ${FILE_CONFIG}`
	DB_PW=`echo ${DB_PW} | sed -e "s#';.*##g" -e "s#^.*'##g"`

	return
}


function l2l_site_phplist() {
	l2l_settings_domain

	IS_TYPE="phplist"
	FILE_CONFIG="lists/config/config.php"

	# rsync mods
	# RSYNC_SITE_INC_EXC=

	if [[ -n ${IS_LIVE} ]]
	then
		return
	fi

	# file mods
	# LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]=

	# db mods
	# LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]=
}


function l2l_get_config_oscommerce() {
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
	l2l_settings_domain

	IS_TYPE="oscommerce"
	FILE_CONFIG="includes/configure.php"

	# rsync mods
	# RSYNC_SITE_INC_EXC=

	if [[ -n ${IS_LIVE} ]]
	then
		return
	fi

	# file mods
	LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="perl -pi -e \"s#${REMOTE_DIR_WWW}#${LOCAL_DIR_WWW}#g\" ${FILE_CONFIG} admin/${FILE_CONFIG}"
	LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="perl -pi -e \"s#(www\.)?${DOMAIN_NAME}#${DOMAIN_LOCALHOST}#g\" ${FILE_CONFIG} admin/${FILE_CONFIG}"
	LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="perl -pi -e \"s#https#http#g\" ${FILE_CONFIG} admin/${FILE_CONFIG}"
	LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="perl -pi -e \"s#'ENABLE_SSL_CATALOG', 'true'#'ENABLE_SSL_CATALOG', 'false'#g\" ${FILE_CONFIG} admin/${FILE_CONFIG}"

	# db mods
	# LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]=
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

	l2l_settings_site
}


function l2l_site_xtcommerce() {
	l2l_settings_domain

	IS_TYPE="xtcommerce"
	FILE_CONFIG="includes/configure.php"

	# rsync mods
	# RSYNC_SITE_INC_EXC=

	if [[ -n ${IS_LIVE} ]]
	then
		return
	fi

	# file mods
	# LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]=

	# db mods
	# LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]=
}


function l2l_get_config_xtcommerce() {
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


function l2l_get_config_wordpress() {
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
	l2l_settings_domain

	IS_TYPE="wordpress"
	FILE_CONFIG="wp-config.php"

	# rsync mods
	RSYNC_SITE_INC_EXC="--include=wp-content/cache/ --exclude=**/wp-content/cache/** --include=wp-content/w3tc/ --exclude=**/wp-content/w3tc/**"

	if [[ -n ${IS_LIVE} ]]
	then
		return
	fi

	# file mods
	# need to disable this in wp-config.php, else no login
	LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="perl -pi -e \"s#^(define\(\s?'COOKIE_DOMAIN', '${DOMAIN_NAME}'.*$)#// \1#g\" wp-config.php"
	LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="perl -pi -e \"s#^(define\(\s?'WP_HOME'.*$)#// \1#g\" wp-config.php"
	LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="perl -pi -e \"s#^(define\(\s?'WP_SITEURL'.*$)#// \1#g\" wp-config.php"
	LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="perl -pi -e \"s#^(define\(\s?'WP_CACHE'.*$)#// \1#g\" wp-config.php"
	LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="perl -pi -e \"s#^(define\(\s?'WPCACHEHOME'.*$)#// \1#g\" wp-config.php"
    LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="echo 'Turn off auto-posting and caching like plugins'"
    # LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="if [ -e 'wp-content/plugins/cdn-sync-tool/' ]; then chmod a= wp-content/plugins/cdn-sync-tool/; fi;"
    # LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="if [ -e 'wp-content/plugins/wp-super-cache/' ]; then chmod a= wp-content/plugins/wp-super-cache/; fi;"
    LOCAL_BASE_MODS[(( LOCAL_BASE_MODS_I++ ))]="open ${HTTP_DOMAIN_LOCALHOST}/wp-admin/plugins.php?plugin_status=active"

	# db mods
	LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]="UPDATE wp_options SET option_value = '${HTTP_DOMAIN_LOCALHOST}' WHERE option_value LIKE '${HTTP_DOMAIN_NAME}';"

	LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]="UPDATE wp_options SET option_value = '${HTTP_DOMAIN_LOCALHOST}' WHERE option_value LIKE '${HTTP_DOMAIN_NAME}/';"

	LOCAL_BASE_DB_MODS[(( LOCAL_BASE_DB_MODS_I++ ))]="UPDATE wp_posts SET post_content = REPLACE(post_content, '${HTTP_DOMAIN_NAME}', '${HTTP_DOMAIN_LOCALHOST}') ;"
}


function l2l_site_wordpress_multisite() {
	l2l_site_wordpress

	# rsync mods
	# RSYNC_SITE_INC_EXC=

	if [[ -n ${IS_LIVE} ]]
	then
		return
	fi

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
}


l2l_run_once