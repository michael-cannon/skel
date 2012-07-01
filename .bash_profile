# .bash_profile is executed for login shells
#
# @author Michael Cannon, michael@typo3vagabond.com
# @version $Id: .bash_profile,v 1.8 2011/09/28 07:53:06 peimic.comprock Exp $

# .bashrc is executed for interactive non-login shells
if [[ -f ~/.bashrc ]]
then
	. ~/.bashrc
fi

# Load common variables to interactive and not
if [[ -f ~/.skel/.bash_var.set ]]
then
	. ~/.skel/.bash_var.set
fi

# load custom settings
if [[ -f ~/.bash_profile.custom ]]
then
	. ~/.bash_profile.custom
fi

# load server specific settings
if [[ -f ~/.bash_profile.${HOSTNAME} ]]
then
	. ~/.bash_profile.${HOSTNAME}
fi

# load host and user specific settings
if [[ -f ~/.bash_profile.${HOSTNAME}.${LOGNAME} ]]
then
	. ~/.bash_profile.${HOSTNAME}.${LOGNAME}
fi

# Unload common variables to interactive and not
if [[ -f ~/.skel/.bash_var.unset ]]
then
	. ~/.skel/.bash_var.unset
fi
