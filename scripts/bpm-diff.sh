#!/bin/bash

if [ x$2 = x ]; then
	echo bpm-diff: Print differences in bpm installations
	echo
	echo Usage: $0 LEFT RIGHT
	echo 'LEFT and RIGHT are one of live, bpm (=live), stage and dev[1-4].'
	exit 1
fi

LEFT=$1
RIGHT=$2

if [ x$LEFT = xlive ]; then
	LEFT=bpm
fi

if [ x$RIGHT = xlive ]; then
	RIGHT=bpm
fi

LEFTDIR=`mktemp -td leftXXXXXXXXXX` || exit 1
RIGHTDIR=`mktemp -td rightXXXXXXXXXX` || exit 1

# collect data about left
pushd /home/$LEFT/public_html/bpminstitute > /dev/null
ls -d1 * | grep -v typo3temp > $LEFTDIR/list
ls -d1 */* | grep -v typo3temp >> $LEFTDIR/list
ls -d1 typo3conf/ext/* >> $LEFTDIR/list.ext
cat $LEFTDIR/list.ext >> $LEFTDIR/list
ls -d1 typo3conf/ext/*/* >> $LEFTDIR/list
ls -d1 typo3conf/ext/*/*/* >> $LEFTDIR/list
sort $LEFTDIR/list > $LEFTDIR/list.sorted
popd > /dev/null

# collect data about right
pushd /home/$RIGHT/public_html/bpminstitute > /dev/null
ls -d1 * | grep -v typo3temp > $RIGHTDIR/list
ls -d1 */* | grep -v typo3temp >> $RIGHTDIR/list
ls -d1 typo3conf/ext/* >> $RIGHTDIR/list.ext
cat $RIGHTDIR/list.ext >> $RIGHTDIR/list
ls -d1 typo3conf/ext/*/* >> $RIGHTDIR/list
ls -d1 typo3conf/ext/*/*/* >> $RIGHTDIR/list
sort $RIGHTDIR/list > $RIGHTDIR/list.sorted
popd > /dev/null

EXTENSIONS=`cat $LEFTDIR/list.ext $RIGHTDIR/list.ext | sort | uniq -c | grep 2 | cut -d"2" -f2- | tr -d "\t" | tr "\n" " "`
for ext in $EXTENSIONS; do
	EXTKEY=`echo $ext | cut -d/ -f3`
	diff -ur /home/$RIGHT/public_html/bpminstitute/$ext /home/$LEFT/public_html/bpminstitute/$ext > $LEFTDIR/$EXTKEY.diff
# delete empty diffs
	if [ ! -s $LEFTDIR/$EXTKEY.diff ]; then
		rm -f $LEFTDIR/$EXTKEY.diff
	fi
done

diff -u $RIGHTDIR/list.sorted $LEFTDIR/list.sorted > $LEFTDIR/list.diff
echo "#####################################"
echo Files in $LEFT that aren\'t in $RIGHT
echo "#####################################"
grep ^+ $LEFTDIR/list.diff | grep -v ^+++
echo "#####################################"
echo Files in $RIGHT that aren\'t in $LEFT
echo "#####################################"
grep ^- $LEFTDIR/list.diff | grep -v ^---
rm -rf $LEFTDIR
rm -rf $RIGHTDIR