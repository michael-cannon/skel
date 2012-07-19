#!/bin/bash
#
#1 parameter : file to rotate

# This sets the number of the weekday where the main file will be renamed.
# Sunday is 0
# -1 means never save
# Call this script BEFORE you make the tag into the filename of "ROTATE_FILE" 

WEEKDAY_TO_SAVE=-1
ROTATE_FILE=$1
TIMESTAMP=`date '+%d%m%y'`
WEEKDAY=`date '+%w'`

# Rotate files
for i in 3 2 1 
do
  ii=`expr $i + 1`
  if test -e $ROTATE_FILE.$i
  then 
    /bin/mv $ROTATE_FILE.$i $ROTATE_FILE.$ii
  fi
done

if test -e $ROTATE_FILE
then
  /bin/mv $ROTATE_FILE $ROTATE_FILE.1
fi

#If WEEKDAY_TO_SAVE...
if [ $WEEKDAY -eq $WEEKDAY_TO_SAVE ]
then
  /bin/mv $ROTATE_FILE.1 $ROTATE_FILE.$TIMESTAMP
fi
