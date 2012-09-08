#! /bin/sh
# http://whmscripts.net/wp-content/uploads/downloads/2010/07/postcpbackup2.txt
#==============================================================================
#  postcpbackup
#   rotate last N monthly and weekly cpanel backups
#   can be set to do daily as well
#
#   Removes old backups and rotates more recent backups so you can retain
#   a little more history, Without this cPanel provides one daily, one weekly,
#   and one monthly backup.  If the monthly has just been overwritten you'll
#   have no history!
#
#   We go to some care to retain a dummy weekly and monthly directory so
#   cpbackup works correctly, as it uses their age (>29 days) to trigger the
#   weekly (>7 days) and monthly (> 29 days).  A real backup creates a
#   "files" directory so we test for the presence of that.
#
#   The three blocks of code below are identical apart from the backup
#   type (daily/weekly/monthly), but making them into one loop would
#   mean use of eval etc which is going to make them hard to understand!
#
#   I think "tac" could be replaced with the ls "-r" option, but untested.
#
#   run with "test=echo /scripts/postcpbackup" to see what it would do
#
#   Author: Brian Coogan, WhiteDogGreenFrog, Sept 2008
#
#==============================================================================

# number of each to keep... comment out to skip that rotation
# keepmonthly=3
keepweekly=6
keepdaily=7

export PATH=$PATH:/usr/local/sbin:/usr/local/bin
export POSTCPBACKUP=$$

if testing=echo system.backup 2>/dev/null 1>&2
then
   # backup system directories with optional script
   system.backup
fi


$debug cd /backup/cpbackup || exit 1
test -s .postcpbackup && . .postcpbackup

# daily backup - if daily is new, archive it and rotate archives
if [ "$keepdaily" != "" -a -d daily/files ]
then
    (( keepdaily++ ))
    cdate=$(date +"%Y%m%d")
    $test mv daily daily_$cdate
    $test mkdir daily
    ls -d daily?* 2>/dev/null | tac | tail -n +$keepdaily |
	xargs -r $test rm -rf 2>/dev/null
fi

# if the weekly backup is new, archive it and rotate archives
if [ "$keepweekly" != "" -a -d weekly/files ]
then
    (( keepweekly++ ))
    cdate=$(date +"%Y%m%d")
    $test mv weekly weekly_$cdate
    $test mkdir weekly
    ls -d weekly?* 2>/dev/null | tac | tail -n +$keepweekly |
	xargs -r $test rm -rf 2>/dev/null
fi

# if the monthly backup is new, archive it and rotate archives
if [ "$keepmonthly" != "" -a -d monthly/files ]
then
    (( keepmonthly++ ))
    cdate=$(date +"%Y%m")
    $test mv monthly monthly_$cdate
    $test mkdir monthly
    ls -d monthly?* 2>/dev/null | tac | tail -n +$keepmonthly |
	xargs -r $test rm -fr 2>/dev/null
fi

exit 0

# -end-
