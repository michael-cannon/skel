#!/bin/sh
#
# Quick script to grab reserve ipv4 list and create new reserved network file
#
# @author Michael Cannon <michael@typo3vagabond.com>

# URL of reserved ips to retrieve
RESERVED_URL='http://www.iana.org/assignments/ipv4-address-space'

# Working filename
RESERVED_FILE='/tmp/ipv4-address-space'

# etc reserved filepath
NETWORKS='/etc/apf/internals/reserved.networks'

# reserved keywords
RESERVED_WORDS='IANA - Reserved'

# filewall restart command
APF_RESTART='/etc/apf/apf --restart'

# now
DATE=`date +'%F_%T'`

# bail if no networks file
if [ ! -f ${NETWORKS} ]
then
	echo No ${NETWORKS} file to update.
	echo Exiting updater
	exit
fi

# grab reserved ips from web
wget -O ${RESERVED_FILE} ${RESERVED_URL}

# grep file for RESERVED_WORDS
# output grep to new file
grep "${RESERVED_WORDS}" ${RESERVED_FILE} > ${RESERVED_FILE}.new

# rename back to orignal
mv ${RESERVED_FILE}.new ${RESERVED_FILE}

# save 000 or else next line removes
perl -pi -e "s#(000)/.+#\X.0.0.0/8#g" ${RESERVED_FILE}

# remove leading 0s
perl -pi -e "s#^0##g" ${RESERVED_FILE}
perl -pi -e "s#^0##g" ${RESERVED_FILE}

# convert ip entries from 1/8 to 1.0.0.0/8
perl -pi -e "s#^([0-9]+)/.+#\1.0.0.0/8#g" ${RESERVED_FILE}

# restore 000 
perl -pi -e "s#^X#0#g" ${RESERVED_FILE}

# add header
echo "# Unassigned/reserved address space" >> ${RESERVED_FILE}
echo "# refer to: http://www.iana.org/assignments/ipv4-address-space" \
	>> ${RESERVED_FILE}
echo "# generated on ${DATE}" >> ${RESERVED_FILE}

# copy current networks file to old
cp ${NETWORKS} ${NETWORKS}.${DATE}

# install new networks file
cp ${RESERVED_FILE} ${NETWORKS}

# restart firewall
${APF_RESTART}
