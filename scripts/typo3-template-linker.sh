#!/bin/bash

# Lookup current templates and link to orignal in fieadmin
#
# @author Michael Cannon <michael@typo3vagabond.com>

# pull in original name
if [ ! "$1" ]
then
	echo "Usage: `basename $0` template-uri"
	echo "Example: \"bpm@bsg:+min/uploads/tx_ttnews $ typo3-template-linker.sh ../../bpminstitute.org/news_template.roundtable.tmpl\""
	exit 65
fi

BAK=".bak"

TEMPLATE_ORIG=$1
echo to ${TEMPLATE_ORIG}
TEMPLATE_BASE=`basename ${TEMPLATE_ORIG}`
echo tb ${TEMPLATE_BASE}
TEMPLATE=`echo ${TEMPLATE_BASE} | sed -e "s#\.\(gif\|jpg\|png\|tmpl\|html\?\)##g"`
echo t ${TEMPLATE}
TEMPLATE_EXT=`echo ${TEMPLATE_BASE} | sed -e "s#.*\.\(gif\|jpg\|png\|tmpl\|html\?\)#\1#g"`
echo te ${TEMPLATE_EXT}

# look up current files with basename
for FILE in `ls ${TEMPLATE}.${TEMPLATE_EXT} ${TEMPLATE}_*.${TEMPLATE_EXT}`
do
	# cycle through each filename like original
	echo ${FILE}

	if [ -L ${FILE} ]
	then
		echo remove current file link
		echo rm ${FILE}
		rm ${FILE}
	elif [ -e ${FILE} ]
	then
		echo mv file to bak
		echo ${FILE} ${FILE}${BAK}
		mv ${FILE} ${FILE}${BAK}
	fi

	echo symlink file to original
	echo ln -s ${TEMPLATE_ORIG} ${FILE}
	ln -s ${TEMPLATE_ORIG} ${FILE}
done