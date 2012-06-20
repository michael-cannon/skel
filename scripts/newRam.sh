#!/bin/sh

# Mass create current ram files 
# 
# @author Michael Cannon <michael@peimic.com>
# @version $Id: newRam.sh,v 1.1.1.1 2010/04/14 09:05:44 peimic.comprock Exp $

TEMP='temp'
DOMAIN='www.bpminstitute.org'
BASE_DIR=`pwd`

for DIR in `find . -type d -maxdepth 1 ! -name ".*"`
do
	DIR=`echo ${DIR} | sed -e "s#^\./##g"`
	cd ${DIR}

	# remove old ram files
	rm *.ram

	# create new ram files
	rm2ram ${DOMAIN}

	# return home
	cd ${BASE_DIR}
done
