#!/bin/sh
# TYPO3cleaner.sh
# @ref http://www.typofree.org/article/archive/2008/june/title/typo3-housekeeping-part-2/

php=`which php`
webroot="/var/www/"
script="/typo3/cli_dispatch.phpsh lowlevel_cleaner"


# Cleaning commands
clean () {
	$command orphan_records -r -v 2 $options
	$command versions -r -v 2 $options
	$command tx_templavoila_unusedce -r --refindex update -v 2 $options
	$command double_files -r --refindex update -v 2 $options
	$command deleted -r -v 1 $options
	$command missing_relations -r --refindex update -v 2 $options
	$command cleanflexform -r -v 2 $options
	$command rte_images -r --refindex update -v 2 $options
	$command missing_files -r --refindex update -v 2 $options
	$command lost_files -r --refindex update -v 2 $options
}


# Usage message
usage () {
	echo "Usage:\n`basename $0` [-d(ryrun)] [-a(utofix)] [-y(es)] [-q(uiet)] domain-name"
}


# get options
while getopts ':adqy' FLAG
do
	case "$FLAG" in
		'a') options="$options --AUTOFIX" ;;
		'd') options="$options --dryrun" ;;
		'q') options="$options --quiet" ;;
		'y') options="$options --YES" ;;
		'?') usage; exit 1;;
	  esac
done
shift $(($OPTIND - 1))

if [ -z "$1" ]
then
	usage
	exit
fi


# Initialize variables
if [ -e $webroot$1 ]
then
	domain=$1
	command="$php $webroot$domain$script"
	clean
else
	echo "Directory does not exist: $webroot$1"
	exit
fi
