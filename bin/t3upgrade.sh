#! /bin/bash
#
# helper script for pulling down TYPO3 zip archive and updating
# also possible to install baseline system
#
# @author Michael Cannon <mc@aihr.us>

# TYPO3 version to pull
if [[ -n ${1} ]]
then 
	VERSION="$1"
else
	# latest LTS TYPO3 version
	VERSION="4.5.19"
fi

# [blankpackage|typo3_src]
if [[ -z ${2} ]]
then
	TYPE="typo3_src"
else
	TYPE=${2}
fi

DIR="${TYPE}-${VERSION}"
FILE="${DIR}.zip"

DATE=`date +'%F'`
TIME=`date +'%T'`
BACKUP_DIR="zzz-typo3-backup-${DATE}_${TIME}"

LOCAL_DIR_WWW=`pwd`
LOCAL_MODS_I=1

if [[ "typo3_src" = ${TYPE} ]]
then
	REPLACEMENTS="typo3
	t3lib
	index.php"
elif [[ "blankpackage" = ${TYPE} ]]
then
	REPLACEMENTS="typo3
	t3lib
	fileadmin
	uploads
	typo3conf
	typo3temp
	clear.gif
	index.php"

	# local file modifications
	LOCAL_MODS[(( LOCAL_MODS_I++ ))]="svn co http://svn.in2code.de/svn/in2code/in2master/trunk typo3conf/ext/in2master"
	LOCAL_MODS[(( LOCAL_MODS_I++ ))]="ln -s typo3conf/ext/in2master/_.htaccess .htaccess"
	LOCAL_MODS[(( LOCAL_MODS_I++ ))]="touch typo3conf/ENABLE_INSTALL_TOOL"

	# pull down the extensions we'd like to use
	LOCAL_MODS[(( LOCAL_MODS_I++ ))]="svn co https://svn.typo3.org/TYPO3v4/Extensions/nc_staticfilecache/tags/2-3-5/ typo3conf/ext/nc_staticfilecache"
	LOCAL_MODS[(( LOCAL_MODS_I++ ))]="svn co https://svn.typo3.org/TYPO3v4/Extensions/realurl/tags/1_12_1/ typo3conf/ext/realurl"
	LOCAL_MODS[(( LOCAL_MODS_I++ ))]="svn co https://svn.typo3.org/TYPO3v4/Extensions/static_info_tables/tags/Version-2-3-0/trunk/ typo3conf/ext/static_info_tables"
	LOCAL_MODS[(( LOCAL_MODS_I++ ))]="svn co https://svn.typo3.org/TYPO3v4/Extensions/tq_seo/tags/5.0.0/ typo3conf/ext/tq_seo"
	LOCAL_MODS[(( LOCAL_MODS_I++ ))]="svn co https://svn.typo3.org/TYPO3v4/Extensions/wt_spamshield/tags/0.8.0/ typo3conf/ext/wt_spamshield"
#	LOCAL_MODS[(( LOCAL_MODS_I++ ))]="svn co https://svn.typo3.org/TYPO3v4/Extensions/js_css_optimizer/tags/1.1.12/ typo3conf/ext/js_css_optimizer"

	# LOCAL_MODS[(( LOCAL_MODS_I++ ))]="echo '<?php $TYPO3_CONF_VARS[\'BE\'][\'installToolPassword\'] = md5(\'HGo!^dy50x\'); ?>' >> typo3conf/localconf.php"
fi

# helper functions
source ~/.skel/scripts/live2local.sh

wget -c http://downloads.sourceforge.net/project/typo3/TYPO3%20Source%20and%20Dummy/TYPO3%20${VERSION}/${FILE}

if [[ -e ${FILE} ]]
then
	unzip ${FILE}
	rm ${FILE}
	mkdir -p ${BACKUP_DIR}

	for REPLACE in ${REPLACEMENTS}
	do
		if [[ -L ${REPLACE} ]]
		then
			rm ${REPLACE}
		fi

		if [[ -e ${REPLACE} ]]
		then
			mv ${REPLACE} ${BACKUP_DIR}/.
		fi

		mv ${DIR}/${REPLACE} .
	done

	l2l_cd
	LOCAL_MODS[(( LOCAL_MODS_I++ ))]="rm -f typo3conf/temp_CACHED_*.php"
	LOCAL_MODS[(( LOCAL_MODS_I++ ))]="rm -rf typo3temp/*"
	l2l_local_media_mods
	# l2l_perms_restore

	mv ${DIR} ${BACKUP_DIR}/.

	l2l_display "Backups in ${BACKUP_DIR}"
else
	l2l_display "${FILE} unable to be downloaded. TYPO3 not upgraded."
fi