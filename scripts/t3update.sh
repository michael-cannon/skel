#!/bin/bash
#
######################################################################
### TYPO3 Update Script ##############################################
######################################################################
#
#--[ LIZENZ ]---------------------------------------------------------
#
# Copyright (c) 2009 - 2011 Peter Kraume <typo3@k-w-s.net>
# All rights reserved.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#
#--[ README ]---------------------------------------------------------
#
# Updates werden hier veroeffentlicht:
# http://forum.df.eu/forum/showthread.php?t=51430
#
# Dieses Script ist fuer ein semi-automatisches Update von TYPO3
# Installationen bei domainfactory, insbesondere dem Reseller Tool RP
# gedacht. Hauptanwendungsbereich ist die Installation von Bugfix
# Releases von TYPO3.
#
# Funktionen aus dem Install Tool, z.B. das setzen von
# [SYS][compat_version] oder ein compare im Database Analyzer werden
# durch das Script NICHT uebernommen!
#
# Was macht das Script genau?
# - Runterladen des gewuenschten Source von typo3.org
# - entpacken des Source
# - Source Tarball wieder loeschen
# - .htaccess Dateien fuer mod_expires durch umbennnen aktivieren
# - alten Symlink im Dummy Verzeichnis loeschen
# - neuen Symlink anlegen
# - index.php aus Source Verzeichnis in Dummy Verzeichnis kopieren
# - neuen Encryption Key generieren
# - Cache Tabellen in der Datenbank leeren
# - temp_CACHED_* Dateien aus /typo3conf loeschen
# - Generierung eines neuen Encryption Keys
#
# Die Nutzung dieses Scripts erfolgt auf eigene Gefahr! Vor jedem
# Update sind Backups anzufertigen!
#
# Teile dieses Scripts wurden dem TYPO3 mass upgrade script von Michiel
# Roos entnommen oder dadurch inspiriert:
# http://www.typofree.org/article/archive/2009/january/title/typo3-mass-upgrade-script/
#
#--[ Installation / Nutzung ]-----------------------------------------
#
# Voraussetzung ist eine Symlink Installation von TYPO3 und ein SSH
# Zugang. Per Default wird davon ausgegangen, dass der TYPO3 Source in
# der Regel immer in einem Unterverzeichnis des in der Variablen
# SRC_DIR bezeichneten Verzeichnisses gespeichert ist.
# Desweiteren wird davon ausgegangen, dass sich dieses Shell Script im
# Ordner unterhalb des Document Roots befindet. Das Dummy Verzeichnis
# laesst sich ueber die Variable DUMMY_DIR anpassen.
# Ueber die Variablen laesst sich das Script leicht an eigene Beduerfnisse
# anpassen.
#
# Das Script muss in jede RP Instanz kopiert werden, da bei df kein
# zentraler Zugriff auf alle TYPO3 Instanzen moeglich ist.
#
# Um das Script nutzen zu koennen muss es ausfuehrbar gemacht werden:
#	chmod +x t3update.sh
#
# Aufruf des Scripts:
#	./t3update.sh
#
# Im Script gibt es ein paar Yes/No Entscheidungen. Der jeweilige Default
# Wert ist durch einen Grossbuchstaben sichtbar, z.B. Y/n
# In diesem Fall entspricht ein Enter dem Y und man kann sich die Eingabe
# sparen
#
#--[ CHANGELOG ]------------------------------------------------------
#
# 31.01.2011
#   * Release von Version 0.4.3
#   * Bugfix: wget Befehl modifiziert um ?download Parameter zu entfernen
#   * Change: Modifikation der Datei typo3/cli_dispatch.phpsh entfernt
#             Skript stattdessen wie folgt aufrufen:
#             `/bin/env -i /usr/local/bin/php5 -f /pfad/zu/typo3/cli_dispatch.phpsh scheduler`
#
# 19.08.2010
#   * Release von Version 0.4.2
#   * Bugfix: .htaccess Prüfung überarbeitet
#   * Bugfix: Umlaute ersetzt wegen fehlerhafter Darstellung unter Mac OS X
#
# 19.04.2010
#   * Release von Version 0.4.1
#   * Bugfix: Falsches Source Verzeichnis, wenn SRC_DIR neu gesetzt wurde
#     (Danke an Stefan Busemann)
#   * Kleine Verbesserungen, wenn Pfade neu gesetzt werden
#
# 09.04.2010
#   * Release von Version 0.4
#   * Pruefung, ob die .htaccess Dateien fuer mod_expires bereits aktiviert
#     sind (das ist seit TYPO3 4.3 standardmaessig der Fall)
#   * Generierung eines neuen Encryption Keys, da viele Installationen
#     immer noch einen schwachen Key verwenden
#   * Cache Tabellen in der Datenbank leeren
#   * Pfad zu PHP in cli_dispatch.phpsh aendern
#   * Code Cleanup und mehr Kommentare
#
# 09.02.2009
#   * Release von Version 0.3
#   * Pruefung, ob Source Download erfolgreich war
#   * index.php aus Source Verzeichnis in Dummy Verzeichnis kopieren
#
# 21.01.2009
#   * Release von Version 0.2 (erste oeffentliche Version)
#   * Finetuning
#   * temp_CACHED_ Dateien aus typo3conf loeschen
#   * weitere erklaerende Texte im Script Header
#
# 21.01.2009
#   * Release von Version 0.1
#
#---------------------------------------------------------------------



#--[ Variablen ]------------------------------------------------------

VERSION=0.4.3

SRC_DIR=${HOME}"/files/software/"
DUMMY_DIR=${PWD}"/html/www/"

TYPO3_SRC_URL_PREFIX="http://prdownloads.sourceforge.net/typo3/"
TYPO3_SRC_URL_SUFFIX=".tar.gz?download"
TYPO3_SRC_FILE_PREFIX="typo3_src-"
TYPO3_SRC_FILE_SUFFIX=".tar.gz"

#--[ Funktionen ]-----------------------------------------------------

#
# erzeugt Eingabeaufforderung
#
prompt() {
	echo
	echo ${1}
	echo -n "> "
	read inputvalue
}

#
# Status Meldungen ausgeben
#
echoStatus() {
	echo
	echo "-----[" ${1} "]-----"
}

#
# TYPO3 Source von typo3.org holen und entpacken
#
getTYPO3source() {
	# SRC_DIR abfragen
	prompt "Soll als Source Verzeichnis ${SRC_DIR} verwendet werden? (Y/n):"
	
	case ${inputvalue} in
		N|n)
		setSrcDir
		;;
	esac
	
	# pruefen, ob SRC_DIR gueltig ist
	if [ ! -d ${SRC_DIR} ]; then
		echo "Fehler: der angegebene Pfad ist ungueltig!"
		setSrcDir
	fi
	
	# pruefen, ob TYPO3 nicht vielleicht schon runtergeladen wurde
	if [ -d ${TYPO3_SRC_TOTAL} ]; then
		echoStatus "TYPO3 Source existiert bereits, Download wird uebersprungen"
		return
	fi

	cd ${SRC_DIR}

	echoStatus "Hole Source von typo3.org"
	echo
	wget -nc -O ${TYPO3_SRC_FILE} ${TYPO3_SRC_URL}

	# pruefen, ob der Source erfolgreich runtergeladen wurde
	if [ ! -f ${TYPO3_SRC_FILE} ]; then
		echoStatus "Fehler: Download des Source fehlgeschlagen!";
		exit;
	fi

	echoStatus "Entpacke Source"
	tar xzf ${TYPO3_SRC_FILE}
	
	echoStatus "Loesche Tarball"
	rm -f ${TYPO3_SRC_FILE}
	
	cd ${TYPO3_SRC_FILE_PREFIX}${TYPO3_VER}
	
	# pruefen, ob .htaccess Dateien bereits vorhanden sind, ansonsten umbenennen
	echoStatus "Aktiviere .htaccess Dateien fuer mod_expires (wenn noetig)"
	
	if [[ ! -e typo3/gfx/.htaccess ]] && [[ -e typo3/gfx/_.htaccess ]]; then
		mv -v typo3/gfx/_.htaccess typo3/gfx/.htaccess
	fi
	
	if [[ ! -e typo3/mod/user/ws/.htaccess ]] && [[ -e typo3/mod/user/ws/_.htaccess ]]; then
		mv -v typo3/mod/user/ws/_.htaccess typo3/mod/user/ws/.htaccess
	fi
	
	if [[ ! -e typo3/sysext/.htaccess ]] && [[ -e typo3/sysext/_.htaccess ]]; then
		mv -v typo3/sysext/_.htaccess typo3/sysext/.htaccess
	fi
	
	if [[ ! -e typo3/sysext/t3skin/stylesheets/.htaccess ]] && [[ -e typo3/sysext/t3skin/stylesheets/_.htaccess ]]; then
		mv -v typo3/sysext/t3skin/stylesheets/_.htaccess typo3/sysext/t3skin/stylesheets/.htaccess
	fi
	
	echoStatus "Neue TYPO3 Version "${TYPO3_VER}" geladen und entpackt"
}

#
# eigentliches Update durchfuehren
#
updateTYPO3() {
	# DUMMY_DIR abfragen
	prompt "Soll als Dummy Verzeichnis ${DUMMY_DIR} verwendet werden? (Y/n):"
	
	case ${inputvalue} in
		N|n)
		setDummyDir
		;;
	esac
	
	# pruefen, ob DUMMY_DIR gueltig ist
	if [ ! -d ${DUMMY_DIR}typo3_src/ ]; then
		echo "Fehler: Keine TYPO3 Installation im gewuenschten Pfad gefunden!"
		setDummyDir
	fi
	
	# letzte Pruefung, ob TYPO3_SRC_TOTAL gueltig ist
	if [ ! -d ${TYPO3_SRC_TOTAL} ]; then
		echo "Fehler: Pfad zum Source Verzeichnis ungueltig!"
		setSrcDir
	fi
	
	cd ${DUMMY_DIR}
	
	echoStatus "Loesche alten Symlink"
	unlink typo3_src
	
	echoStatus "Setze neuen Symlink"
	ln -s ${TYPO3_SRC_TOTAL} typo3_src
		
	echoStatus "Kopiere index.php ins Dummy Verzeichnis"
	rm -f index.php
	cp -f typo3_src/index.php ./
	
	# neuen Encryption Key mit 96 Zeichen generieren
	echoStatus "Generiere neuen Encryption Key"
	k=0
	key=''
	while [ ${k} -lt 96 ]; do
			key=${key}$(head -100 /dev/urandom | md5sum | cut -c1)
			let k++
	done
	echo "neuer Key: ${key}"
	cd ${DUMMY_DIR}
	sed -i "s/\(\$TYPO3_CONF_VARS\['SYS']\['encryptionKey'] = \).*/\1'${key}';/g" typo3conf/localconf.php
	
	# Seiten Cache loeschen
	echoStatus "Leere Seiten Cache Tabellen in der Datenbank"
	
	pageCacheTables=(
		cache_pages
		cache_pagesection
	)
	pageCacheTablesLength=${#pageCacheTables[*]}
	
	database=$(grep "typo_db " typo3conf/localconf.php | tail -1 | sed "s/^[^']*'\([^']*\)'.*/\1/" | grep '$typo_db =')
	if [ -z "${database}" ] ; then
		database=$(grep "typo_db " typo3conf/localconf.php | tail -1 | sed "s/^[^']*'\([^']*\)'.*/\1/")
	else
		database=$(grep "typo_db " typo3conf/localconf.php | tail -1 | sed "s/^[^\"]*\"\([^\"]*\)\".*/\1/")
	fi
	
	username=$(grep "typo_db_username " typo3conf/localconf.php | tail -1 | sed "s/^[^']*'\([^']*\)'.*/\1/" | grep '$typo_db_username =')
	if [ -z "${username}" ] ; then
		username=$(grep "typo_db_username " typo3conf/localconf.php | tail -1 | sed "s/^[^']*'\([^']*\)'.*/\1/")
	else
		username=$(grep "typo_db_username " typo3conf/localconf.php | tail -1 | sed "s/^[^\"]*\"\([^\"]*\)\".*/\1/")
	fi
	
	password=$(grep "typo_db_password " typo3conf/localconf.php | tail -1 | sed "s/^[^']*'\([^']*\)'.*/\1/" | grep '$typo_db_password =')
	if [ -z "${password}" ] ; then
		password=$(grep "typo_db_password " typo3conf/localconf.php | tail -1 | sed "s/^[^']*'\([^']*\)'.*/\1/")
	else
		password=$(grep "typo_db_password " typo3conf/localconf.php | tail -1 | sed "s/^[^\"]*\"\([^\"]*\)\".*/\1/")
	fi
	
	host=$(grep "typo_db_host " typo3conf/localconf.php | tail -1 | sed "s/^[^']*'\([^']*\)'.*/\1/" | grep '$typo_db_host =')
	if [ -z "${host}" ] ; then
		host=$(grep "typo_db_host " typo3conf/localconf.php | tail -1 | sed "s/^[^']*'\([^']*\)'.*/\1/")
	else
		host=$(grep "typo_db_host " typo3conf/localconf.php | tail -1 | sed "s/^[^\"]*\"\([^\"]*\)\".*/\1/")
	fi
	
	j=0
	while [ $j -lt $pageCacheTablesLength ];
	do
		nice -n 19 /usr/bin/mysql --batch -u${username} -p"${password}" -h${host} ${database} -e "TRUNCATE ${pageCacheTables[$j]}"
		nice -n 19 /usr/bin/mysql --batch -u${username} -p"${password}" -h${host} ${database} -e "ALTER TABLE ${pageCacheTables[$j]} auto_increment=1"
		echo Tabelle ${pageCacheTables[$j]} geleert
		let j++
	done
		
	# temp_CACHED_* Dateien loeschen
	echoStatus "Loesche temp_CACHED_* Dateien aus /typo3conf"
	cd typo3conf
	rm -fv temp_CACHED_*
	
	# alles fertig :)
	echoStatus "TYPO3 Update erfolgreich abgeschlossen!"
}

#
# neues SRC_DIR setzen
#
setSrcDir() {
	prompt "Bitte bestehenden Pfad, beginnend bei ${HOME}, eingeben:"
	
	# Slash am Anfang einfuegen, wenn keiner da ist
	if [ ! "${inputvalue:0:1}" == "/" ]; then inputvalue="/"${inputvalue}; fi

	# Slash am Ende anhaengen, wenn keiner da ist
	if [ ! "${inputvalue:(-1)}" == "/" ]; then inputvalue=${inputvalue}"/"; fi
	
	# wenn angegebener Pfad ungueltig ist, Funktion erneut aufrufen
	if [ ! -d ${HOME}${inputvalue} ]; then
		echo "Fehler: der angegebene Pfad ist ungueltig!"
		setSrcDir
	else
		SRC_DIR=${HOME}${inputvalue}
		TYPO3_SRC_TOTAL=${SRC_DIR}${TYPO3_SRC_FILE_PREFIX}${TYPO3_VER}/
		echo "neuer Source Pfad: ${SRC_DIR}"
	fi
}

#
# neues DUMMY_DIR setzen
#
setDummyDir() {
	prompt "Bitte bestehenden Pfad, beginnend bei ${HOME}, eingeben:"
	
	# Slash am Anfang einfuegen, wenn keiner da ist
	if [ ! "${inputvalue:0:1}" == "/" ]; then inputvalue="/"${inputvalue}; fi

	# Slash am Ende anhaengen, wenn keiner da ist
	if [ ! "${inputvalue:(-1)}" == "/" ]; then inputvalue=${inputvalue}"/"; fi
	
	# wenn angegebener Pfad ungueltig ist, Funktion erneut aufrufen
	if [ ! -d ${HOME}${inputvalue} ]; then
		echo "Fehler: der angegebene Pfad ist ungueltig!"
		setDummyDir
	else
		DUMMY_DIR=${HOME}${inputvalue}
		echo "neuer Dummy Pfad: ${DUMMY_DIR}"
	fi
}

#--[ los gehts ]------------------------------------------------------
clear
echo
echo "**********************************************************************"
echo "*                                                                    *"
echo "* TYPO3 Update Script ${VERSION}                                          *"
echo "* Copyright (c) 2010 Peter Kraume <typo3@k-w-s.net>                  *"
echo "*                                                                    *"
echo "**********************************************************************"

prompt "Auf welche Version soll das Update von TYPO3 erfolgen? (z.B. 4.4.5): "

TYPO3_VER=${inputvalue}
TYPO3_SRC_FILE=${TYPO3_SRC_FILE_PREFIX}${TYPO3_VER}${TYPO3_SRC_FILE_SUFFIX}
TYPO3_SRC_URL=${TYPO3_SRC_URL_PREFIX}${TYPO3_SRC_FILE_PREFIX}${TYPO3_VER}${TYPO3_SRC_URL_SUFFIX}
TYPO3_SRC_TOTAL=${SRC_DIR}${TYPO3_SRC_FILE_PREFIX}${TYPO3_VER}/

prompt "Soll der neue Source von typo3.org geladen werden? (Y/n):"

case ${inputvalue} in
	N|n)
		echoStatus "Download wird uebersprungen"
		
		# SRC_DIR abfragen
		prompt "Soll als Source Verzeichnis ${SRC_DIR} verwendet werden? (Y/n):"
		
		case ${inputvalue} in
			N|n)
				setSrcDir
			;;
		esac
		
		# pruefen, ob SRC_DIR gueltig ist
		if [ ! -d ${SRC_DIR} ]; then
			echo "Fehler: der angegebene Pfad ist ungueltig!"
			setSrcDir
		fi
		
		TYPO3_SRC_TOTAL=${SRC_DIR}${TYPO3_SRC_FILE_PREFIX}${TYPO3_VER}/
	;;
	*)
		getTYPO3source
	;;
esac

updateTYPO3

echo
exit 0
