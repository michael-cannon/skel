# .bashrc is executed for interactive non-login shells
#
# @author Michael Cannon, michael@typo3vagabond.com
# @version $Id: .bashrc,v 1.5 2011/09/28 07:53:06 peimic.comprock Exp $

# If not running interactively, don't do anything
[[ -z ${PS1} ]] && return

# Source global definitions
if [ -f /etc/bashrc ]
then
	. /etc/bashrc
fi

cd

# no core dumps
ulimit -c 0

# Load common variables to interactive and not
if [[ -f ~/.skel/.bash_var.set ]]
then
	. ~/.skel/.bash_var.set
fi

# rebuild PATH
# hang onto original path
export PATH_ORIG=${PATH}

# list of paths to check for
# in order of precedence
NEW_PATHS="`pwd`/bin/custom
`pwd`/bin
`pwd`/bin/backup
/opt/local/libexec/gnubin
/opt/local/sbin
/opt/local/bin
/opt/local/apache2/bin
/opt/local/lib/mysql5/bin
/opt/local/share/mysql5/mysql
/Applications/MAMP/Library/bin
/Applications/MAMP/bin/php/php5.3.6/bin
/Developer/usr/bin
/usr/kerberos/sbin
/usr/kerberos/bin
/usr/local/mysql/bin
/usr/local/sbin
/usr/local/bin
/usr/sbin
/usr/bin
/sbin
/bin
/usr/X11R6/bin
/cygdrive/c/ProgramFiles/QuickTime/QTSystem/
/cygdrive/c/Users/user/PortableApps/xampp/mysql/bin
/cygdrive/c/Users/user/PortableApps/xampp/php
/cygdrive/c/Windows
/cygdrive/c/Windows/System32/Wbem
/cygdrive/c/Windows/System32/WindowsPowerShell/v1.0/
/cygdrive/c/Windows/system32"

TEMP_PATH=""

# cycle through NEW_PATHS as NEW_PATH
for NEW_PATH in ${NEW_PATHS}
do
	# if NEW_PATH exists and not in current PATH
	# add NEW_PATH to TEMP_PATH
	if [[ -d "${NEW_PATH}" ]]
	then
		TEMP_PATH="${TEMP_PATH}:${NEW_PATH}"
	fi
done

# prepare new path for export
unset NEW_PATH NEW_PATHS
TEMP_PATH=`echo ${TEMP_PATH} | sed -e "s#^:##g"`
export PATH=${TEMP_PATH}
unset TEMP_PATH

if [[ -d /opt/local/share/man ]]
then
	export MANPATH=/opt/local/share/man:$MANPATH
fi

# set cvsroot
if [[ ${OS_REDHAT} == ${HOST_OS} ]] \
	|| [[ ${OS_DARWIN} == ${HOST_OS} ]] \
	|| [[ ${OS_CYGWIN} == ${HOST_OS} ]]
then
	export CVSROOT=:ext:peimic.comprock@peimic.cvs.cvsdude.com:/peimic
	export CVS_RSH=ssh
fi

# UTF-8 encoding
export LC_CTYPE=en_US.UTF-8

# don't put duplicate lines in the history. See bash(1) for more options
# ... or force ignoredups and ignorespace via ignoreboth
HISTCONTROL=ignorespace

# Increase the number of commands recorded
export HISTSIZE=10000
export HISTFILESIZE=10000

# Append commands to the history file, rather than overwrite it.
shopt -s histappend

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# fun things
# correct spelling errors
shopt -s cdspell

# make multiple line commands into one in history
shopt -s cmdhist

# allow .files to be returned
shopt -s dotglob

# ksh-88 regex
# ?(pattern-list)
#     Matches zero or one occurrence of the given patterns 
# *(pattern-list)
#     Matches zero or more occurrences of the given patterns 
# +(pattern-list)
#     Matches one or more occurrences of the given patterns 
# @(pattern-list)
#     Matches exactly one of the given patterns 
# !(pattern-list)
#     Matches anything except one of the given patterns
shopt -s extglob

export HISTTIMEFORMAT='%F %X '

# command prompt length keeper
# @ref http://www.mova.org/~lowry/dotbashrc.html
# how many characters of the $PWD should be kept
PWD_MAX_LENGTH=21

function cut_pwd {
	if [ $HOME == ${PWD:0:${#HOME}} ]
	then
		NEW_PWD="~${PWD:${#HOME}}"
	else
		NEW_PWD=$PWD
	fi

	if [ ${#NEW_PWD} -gt $PWD_MAX_LENGTH ]
	then
		local pwdoffset=$(( ${#NEW_PWD} - $PWD_MAX_LENGTH ))
		NEW_PWD="+${NEW_PWD:$pwdoffset:$PWD_MAX_LENGTH}"
	fi
}

# define the content of the prompt command
function prompt_command {
	cut_pwd
    case $TERM in
      (xterm*)
              echo -ne "\033]0;${USER}($(id -ng))@${HOSTNAME}: ${PWD}\007"
      ;;
    esac
}

# run pwd setup once at startup
cut_pwd

# setting the prompt
export PROMPT_COMMAND=prompt_command

# Save each command right after it has been executed, not at the end of the session.
export PROMPT_COMMAND="history -a;${PROMPT_COMMAND}"

# Source completion code
BASH_COMP="~/bin/bash_completion"
BASH=${BASH_VERSION%.*}
BMAJOR=${BASH%.*}
BMINOR=${BASH#*.}

# root mods
if [ "${LOGNAME}" = "root" ]
then
 	alias rm='rm -i'
 	alias cp='cp -i'
 	alias mv='mv -i'
	BASH_COMP="~/.skel/bin/bash_completion"
fi

# comprock@lilg4:~/Documents $ 
# export PS1='\u@\h:\w \$ '

# comprock@lilg4:...ts/projects/zzz-projects $
export PS1="\u@\h:\${NEW_PWD} \$ "

if [ "${PS1}" ] && [ -f ${BASH_COMP} ]
then
	if [ ${BMAJOR} -eq 2 ] && [ ${BMINOR} '>' 04 ] || [ ${BMAJOR} -gt 2 ]
	then
		${BASH_COMP}
	fi
fi

unset BASH BMAJOR BMINOR BASH_COMP

# colors - see man ls for designations
export CLICOLOR="Yes"
export LSCOLORS=Exfxcxdxbxegedabagacad

if [[ -e /opt/local/libexec/gnubin/ls ]]
then
	export LS_OPTIONS="--color=tty -F -b -T 0 -h"
else
	export LS_OPTIONS="--color"
fi

# how many ways to list something are there?
alias ls="ls ${LS_OPTIONS}"

if [[ -e /opt/local/bin/grep ]]
then
	GREP_OPTIONS="--binary-files=without-match --color=auto --devices=skip --exclude-dir=CVS --exclude-dir=.libs --exclude-dir=.deps --exclude-dir=.svn --exclude-dir=.git"
else
	GREP_OPTIONS="--binary-files=without-match --color=auto --devices=skip --exclude=CVS --exclude=.libs --exclude=.deps --exclude=.svn --exclude=.git"
fi
export GREP_OPTIONS

# ruby helpers
export RUBYOPT=rubygems

WHICH_VIM=`which vim`

if [ ${WHICH_VIM} ] && [ "${WHICH_VIM}" != "No *" ]
then
	alias vi="vim"
	VISUAL=vim
	EDITOR=vim
else
	VISUAL=vi
	EDITOR=vi
fi

export EDITOR
export VISUAL
unset WHICH_VIM

# dir Owner rwx, group rx, users rx
# file Owner rw, group r, users r
# + 7777
# - 0022
# = 7755
umask 0022

# load aliases
if [ -f ~/.alias ]
then
	. ~/.alias
fi

# load conditional aliases
if [ -f ~/.alias.conditional ]
then
	. ~/.alias.conditional
fi

# load ssh aliases
if [ -f ~/.alias.ssh ]
then
	. ~/.alias.ssh
fi

# load host specific settings
if [ -f ~/.bashrc.${HOSTNAME} ]
then
	. ~/.bashrc.${HOSTNAME}
fi

# load host and user specific settings
if [ -f ~/.bashrc.${HOSTNAME}.${LOGNAME} ]
then
	. ~/.bashrc.${HOSTNAME}.${LOGNAME}
fi

# Unload common variables to interactive and not
if [[ -f ~/.skel/.bash_var.unset ]]
then
	. ~/.skel/.bash_var.unset
fi
