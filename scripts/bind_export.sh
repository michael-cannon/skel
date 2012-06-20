#!/bin/sh
# Copyright (c) 2002-2007 by Rack-Soft
# Copyright (c) 2002-2007 by 4PSA (www.4psa.com)
# All rights reserved


# Modified: $DateTime: 2008/11/11 11:52:39 $
# Revision: $Revision: 1.1.1.1 $ with $Change: 43782 $

# DUMPS DNS Zones in the 4PSA DNS Manager 3 dump format
# Compatible with standard bind installations
# Compatible with DNS Manager 3.0.0 and above
# Description: for every zone listed in $named_conf, the script parse and dumps DNS records

# --------------------------------------------------------------------------------
#
# Please modify the default DNS records target (backup file)
# This will be remote update location in 4PSA DNS Manager
# You must include the full path!
# The program can also take a dump destination as the argument

# NOTE that if 1 argument is given dump_file will be the argument
dump_file="dump_full_recs.txt"
dump_temp_file="$dump_file-$$"

# Depending on zone configuration you need chroot or not
#chroot_dir="/var/named/named/run-root"
# p.a chroot_dir="/var/named/run-root"
chroot_dir=""

# You can modify the following parameter to match your environment
named_conf="/etc/named.conf"

# Dump type can be <masters/slaves/both>
dump="masters"

# Converts master zones to slaves in dump (for DNS Manager 3 acting as slave for a bind server)
# Works only when
# dump=masters/both
# dump_allow_transfers=yes/no
# dump_masters=yes/no
masters2slaves="no"

# Dump 'master' records from existing zones and includes them in the dump
# Works only when:
# dump=slaves/both
# masters2slaves=yes/no (Zones transformed from master2slave can not have a
# masters record because it does not exist in database!)
# dump_allow_transfers="yes"
dump_masters="yes"

# Dump 'allow-transfer' servers from existing zones and includes them in the dump
# Works only when:
# dump=master/both
# dump_masters=yes/no
# masters2slaves=yes/no
dump_allow_transfers="yes"

# Dump reverse zones
dump_reverse="yes"


# DO NOT MODIFY ANYTHING BELOW THIS LINE UNLESS YOU KNOW WHAT YOU ARE DOING
# -------------------------------------------------------------------------

get_config()
{
if [ ! -f ${named_conf} ]; then
        echo "Config file does not exist, exiting."
        exit 1
fi
}

is_root()
{
        current_user="`id`"
        case ${current_user} in
                uid=0\(root\)*)
                                ;;
                            *)
                                echo "$0: You must have root privileges to run this script"
                                echo "Su as root and try again"
                                echo
                                exit 1
                                ;;
        esac
}

determine_mask()
# determine network mask for reverse zones
# $1 is reverse zone name
# returns result inglobal variable $mask
{
        local r_ip
        local ip

        r_ip="`echo "$1" | awk '{ pos=index(tolower($0), ".in-addr.arpa"); ip=substr($0, 1, pos - 1);  print ip}'` "
        if [ ! -z ${r_ip} ]; then
                mask="`echo ${r_ip} | awk 'BEGIN{FS="."}{print NF}'`"
                if [ ! -z ${mask} ]; then
                        return 0
                fi
        fi
return 1
}

get_masters(){
        if [ "$masters2slaves" = "yes" ];then
                local zonetype="slave"
        else
                local zonetype="master"
        fi
        if [ "$dump_reverse" = "yes" ];then
        # REVERSE ZONES
                cat ${named_conf}|tr -s "\n \t" " "|grep -Eo "[ ]*zone.*};"|sed 's/\( zone[ ]*\)/\x0A\1/g;s/{/ {/g'|awk '{gsub("x0A","\n");print}'|awk '(tolower($2)~/^\".+\.in-addr\.arpa\"$/)&&($0~/type[ ]*master/)&&($0~/file[ ]*"[^"]*"/){print $0}' |while read LINE; do
                        ZNAME="`echo $LINE|awk '{gsub(/"/,"",$2);print $2}'|sed 's/ //g'`"
                        rfile="$chroot_dir/$(echo $LINE|grep -Eo "[ ]+file[ ]+\"[^\"]*\""|awk '{buff=gsub(/"/,"",$2);print $buff}'|sed 's/ //g')"
                        if [ ! -f ${rfile} ]; then
                                echo "Error: could not determine path to file for zone $ZNAME."
                        else
                                # filed is divided in 5 of 6 parts
                                determine_mask "$ZNAME"
                                if [ $? -eq 0 ]; then
                                        r_ip="`echo $ZNAME | awk '{if (tolower($1) ~ /^.+\.in-addr\.arpa$/){ pos=index(tolower($0), ".in-addr.arpa"); ip=substr($0, 1, pos - 1);  print ip}}'` "
                                        if [ ! -z ${r_ip} ]; then
                                                #difer=`expr 4 - $mask`
                                                difer=4
                                                ip="`echo ${r_ip} | awk 'BEGIN{FS=".";ORS=" "}{for(i=NF; i>1; i--) printf("%s.",$i); printf("%s",$1)}' mask=${difer}`"
                                                bit_mask="`expr ${mask} \* 8`"
                                                echo "$ZNAME.|$zonetype {" >> ${dump_temp_file}
                                                if [ "$dump_allow_transfers" = "yes" ];then
                                                        local ALLOWTRANSFERS="`echo $LINE|grep -Eo "allow-transfer[\t ]*{[^}]*}"|grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+[\t ]*;"|tr -s ';' ' '`"
                                                        local ALLOWTRANSFER=""
                                                        for ALLOWTRANSFER in $ALLOWTRANSFERS ; do
                                                                echo "|ALLOW_TRANSFER| |$ALLOWTRANSFER| || ||">>${dump_temp_file}
                                                        done
                                                fi


                                                #dump only PTR and NS
                                                if [ "$masters2slaves" = "no" ];then
                                                        buff="`grep -Ev "^[ \t]*;" ${rfile}|tr -s "\r" "\n"|sed 's/;.*//'|awk '
                                                        {
                                                                if (toupper($4)=="TXT"){txt=substr($0,index($0,$5));gsub(/"/,"",txt); printf ("|%s| |%s| |%s| ||\n",toupper($4),$1,txt)};
                                                                if (toupper($3)=="TXT"){txt=substr($0,index($0,$4));gsub(/"/,"",txt); printf ("|%s| |%s| |%s| ||\n",toupper($3),$1,txt)};
                                                                if (toupper($1)=="TXT"){txt=substr($0,index($0,$2));gsub(/"/,"",txt); printf ("|%s| || |%s| ||\n",toupper($1),txt)};
                                                                if ((NF==2)&&(toupper($1) ~ /ORIGIN/))  printf("|$ORIGIN| |%s| || ||\n", $2);
                                                                if ((NF==5)&&(toupper($3)=="IN")&&(toupper($4)=="PTR")&&(toupper($4)!="TXT")) printf("|%s| |%s| |%s| |%s|\n", toupper($4),$1,$5,"'$bit_mask'");
                                                                if ((NF==5)&&(toupper($3)=="IN")&&(toupper($4)=="NS")&&(toupper($4)!="TXT")) printf("|%s| |%s| |%s| ||\n", toupper($4),$1,$5);
                                                                if ((NF==4)&&(toupper($2)=="IN")&&(toupper($3)=="PTR")&&(toupper($3)!="TXT")) printf("|%s| |%s| |%s| |%s|\n", toupper($3),$1,$4,"'$bit_mask'");
                                                                if ((NF==4)&&(toupper($2)=="IN")&&(toupper($3)=="NS")&&(toupper($3)!="TXT")) printf("|%s| |%s| |%s| ||\n", toupper($3),$1,$4);
                                                                if ((NF==5)&&(toupper($3)=="IN")&&(toupper($4)=="CNAME")&&(toupper($4)!="TXT")) printf("|%s| |%s| |%s| ||\n", toupper($4),$1,$5);
                                                                if ((NF==4)&&(toupper($2)=="IN")&&(toupper($3)=="CNAME")&&(toupper($3)!="TXT")) printf("|%s| |%s| |%s| |%s|\n", toupper($3),$1,$4,"'$bit_mask'");
                                                                if ((NF==3)&&(toupper($2)=="CNAME")&&(toupper($1)!="IN"))  printf("|%s| |%s| |%s| ||\n", toupper($2),$1,$3);
                                                                if ((NF==3)&&(toupper($2)=="CNAME")&&(toupper($1)=="IN"))  printf("|%s| || |%s| ||\n", toupper($2),$3);
                                                                if ((NF==2)&&(toupper($1)=="NS"))  printf("|%s| || |%s| ||\n", toupper($1),$2);
                                                                if ((NF==2)&&(toupper($1)=="PTR"))  printf("|%s| || |%s| ||\n", toupper($1),$2);              
                                                                if ((NF==3)&&(toupper($2)=="PTR"))  printf("|%s| |%s| |%s| ||\n", toupper($2),$1,$3);         
                                                                if ((NF==2)&&(toupper($1)=="A"))  printf("|%s| || |%s| ||\n", toupper($1),$2);
                                                                if ((NF==3)&&(toupper($2)=="A")&&(toupper($1)!="IN"))  printf("|%s| |%s| |%s| ||\n", toupper($2),$1,$3);
                                                                if ((NF==2)&&(toupper($1)=="MX"))  printf("|%s| || |%s| ||\n", toupper($1),$2);
                                                                if ((NF==3)&&(toupper($1)=="MX"))  printf("|%s| || |%s| |%s|\n", toupper($1),$3,$2);
                                                                if ((NF==3)&&(toupper($2)=="NS")&&(toupper($1)=="IN"))  printf("|%s| || |%s| ||\n", toupper($2),$3);
                                                                if ((NF==3)&&(toupper($2)=="A")&&(toupper($1)=="IN"))  printf("|%s| || |%s| ||\n", toupper($2),$3);
                                                                if ((NF==3)&&(toupper($2)=="MX")&&(toupper($1)=="IN"))  printf("|%s| || |%s| |%s|\n", toupper($2),$3,$4);
                                                                if ((NF==4)&&(toupper($1)=="IN")&&(toupper($2)=="MX")) printf("|%s| || |%s| |%s|\n", toupper($2),$4,$3);
                                                        }
                                                        '`"
                                                        echo "${buff}" >> ${dump_temp_file}
                                                fi
                                                echo "}" >> ${dump_temp_file}
                                        else
                                                echo "Error: unknown PTR record structure for reverse zone $ZNAME"
                                        fi
                                else
                                        echo "Error: invalid reverse zone name $ZNAME"
                                fi
                        fi
                done
        fi
        # FORWARD ZONES
        cat ${named_conf}|tr -s "\n \t" " "|grep -Eo "[ ]*zone.*};"|sed 's/\( zone[ ]*\)/\x0A\1/g;s/{/ {/g'|awk '{gsub("x0A","\n");print}'|awk '(tolower($2)!~/^\".+\.in-addr\.arpa\"$/)&&($0~/type[ ]*master/)&&($0~/file[ ]*"[^"]*"/){print $0}' |while read LINE; do
                ZNAME="`echo $LINE|awk '{gsub(/"/," ",$2);print $2}'|sed 's/ //g'`"
                file="$chroot_dir/$(echo $LINE|grep -Eo "[ ]+file[ ]+\"[^\"]*\""|awk '{gsub(/"/," ",$2);print $2}'|sed 's/ //g')"
                if [ ! -f ${file} ]; then
                        echo "Error: could not determine path to file for zone $ZNAME."
                else
                        echo "$ZNAME.|$zonetype {" >> ${dump_temp_file}
                        if [ "$dump_allow_transfers" = "yes" ];then
                                local ALLOWTRANSFERS="`echo $LINE|grep -Eo "allow-transfer[\t ]*{[^}]*}"|grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+[\t ]*;"|tr -s ';' ' '`"
                                local ALLOWTRANSFER=""
                                for ALLOWTRANSFER in $ALLOWTRANSFERS ; do
                                        echo "|ALLOW_TRANSFER| |$ALLOWTRANSFER| || ||">>${dump_temp_file}
                                done
                        fi
                        if [ "$masters2slaves" = "no" ];then
                                buff="`grep -Ev "^[ \t]*;" ${file}|tr -s "\r" "\n"|sed 's/;.*//'|awk '
                                {
                                        if (toupper($4)=="TXT"){txt=substr($0,index($0,$5));gsub(/"/,"",txt); printf ("|%s| |%s| |%s| ||\n",toupper($4),$1,txt)};
                                        if (toupper($3)=="TXT"){txt=substr($0,index($0,$4));gsub(/"/,"",txt); printf ("|%s| |%s| |%s| ||\n",toupper($3),$1,txt)};
                                        if (toupper($1)=="TXT"){txt=substr($0,index($0,$2));gsub(/"/,"",txt); printf ("|%s| || |%s| ||\n",toupper($1),txt)};
                                        if ((NF==2)&&(toupper($1) ~ /ORIGIN/))  printf("|$ORIGIN| |%s| || ||\n", $2);
                                        if ((NF==4)&&(toupper($2)=="IN")&&(toupper($3)!="MX")&&(toupper($3)!="TXT")) printf("|%s| |%s| |%s| ||\n", toupper($3),$1,$4);
                                        if ((NF==5)&&(toupper($2)=="IN")&&(toupper($3)=="MX")&&(toupper($3)!="TXT")) printf("|%s| |%s| |%s| |%s|\n", toupper($3),$1,$5,$4);
                                        if ((NF==5)&&(toupper($3)=="IN")&&(toupper($4)!="MX")&&(toupper($4)!="TXT")) printf("|%s| |%s| |%s| ||\n", toupper($4),$1,$5);
                                        if ((NF==6)&&(toupper($3)=="IN")&&(toupper($4)=="MX")&&(toupper($4)!="TXT")) printf("|%s| |%s| |%s| |%s|\n", toupper($4),$1,$6,$5);
                                        if ((NF==3)&&(toupper($2)=="CNAME")&&(toupper($1)!="IN"))  printf("|%s| |%s| |%s| ||\n", toupper($2),$1,$3);
                                        if ((NF==3)&&(toupper($2)=="CNAME")&&(toupper($1)=="IN"))  printf("|%s| || |%s| ||\n", toupper($2),$3);
                                        if ((NF==2)&&(toupper($1)=="NS"))  printf("|%s| || |%s| ||\n", toupper($1),$2);
                                        if ((NF==2)&&(toupper($1)=="A"))  printf("|%s| || |%s| ||\n", toupper($1),$2);
                                        if ((NF==3)&&(toupper($2)=="A")&&(toupper($1)!="IN"))  printf("|%s| |%s| |%s| ||\n", toupper($2),$1,$3);
                                        if ((NF==2)&&(toupper($1)=="MX"))  printf("|%s| || |%s| |%s|\n", toupper($1),$2,$3);
                                        if ((NF==3)&&(toupper($1)=="MX"))  printf("|%s| || |%s| |%s|\n", toupper($1),$3,$2);
                                        if ((NF==3)&&(toupper($2)=="NS")&&(toupper($1)=="IN"))  printf("|%s| || |%s| ||\n", toupper($2),$3);
                                        if ((NF==3)&&(toupper($2)=="A")&&(toupper($1)=="IN"))  printf("|%s| || |%s| ||\n", toupper($2),$3);
                                        if ((NF==3)&&(toupper($2)=="MX")&&(toupper($1)=="IN"))  printf("|%s| || |%s| |%s|\n", toupper($2),$3,$4);
                                        if ((NF==4)&&(toupper($1)=="IN")&&(toupper($2)=="MX")) printf("|%s| || |%s| |%s|\n", toupper($2),$4,$3);
                                }
                                '`"
                                echo "${buff}" >> ${dump_temp_file}
                        fi
                        echo "}" >> ${dump_temp_file}
                fi
        done

}

get_slaves(){
        local LINE=""
        cat ${named_conf}|tr -s "\n \t" " "|grep -Eo "[ ]*zone.*};"|sed 's/\( zone[ ]*\)/\x0A\1/g;s/{/ {/g'|awk '{gsub("x0A","\n");print}'|awk  '($2!~/^\".+\.in-addr\.arpa\"$/)&&($0~/type[ ]*slave/){print $0}' |while read LINE; do
                local ZNAME="`echo $LINE|awk '{gsub(/"/," ",$2);print $2}'|sed 's/ //g'`"
                echo "$ZNAME.|slave {" >>${dump_temp_file}
                if [ "$dump_allow_transfers" = "yes" ];then
                        local ALLOWTRANSFERS="`echo $LINE|grep -Eo "allow-transfer[\t ]*{[^}]*}"|grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+[\t ]*;"|tr -s ';' ' '`"
                        local ALLOWTRANSFER=""
                        for ALLOWTRANSFER in $ALLOWTRANSFERS ; do
                                echo "|ALLOW_TRANSFER| |$ALLOWTRANSFER| || ||">>${dump_temp_file}
                        done
                fi
                if [ "$dump_masters" = "yes" ];then
                        local MASTERS="`echo $LINE|grep -Eo "masters[\t ]*{[^}]*}"|grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+[\t ]*;"|tr -s ';' ' '`"
                        local MASTER=""
                        for MASTER in $MASTERS ; do
                                echo "|MASTER| |$MASTER| || ||">>${dump_temp_file}
                        done
                fi
                echo "}" >>${dump_temp_file}
        done
        if [ "$dump_reverse" = "yes" ];then
        # REVERSE ZONES
                cat ${named_conf}|tr -s "\n \t" " "|grep -Eo "[ ]*zone.*};"|sed 's/\( zone[ ]*\)/\x0A\1/g;s/{/ {/g'|awk '{gsub("x0A","\n");print}'|awk  '($2~/^\".+\.in-addr\.arpa\"$/)&&($0~/type[ ]*slave/){print $0}' |while read LINE; do
                        local ZNAME="`echo $LINE|awk '{gsub(/"/," ",$2);print $2}'|sed 's/ //g'`"
                        echo "$ZNAME.|slave {" >>${dump_temp_file}
                        if [ "$dump_allow_transfers" = "yes" ];then
                                local ALLOWTRANSFERS="`echo $LINE|grep -Eo "allow-transfer[\t ]*{[^}]*}"|grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+[\t ]*;"|tr -s ';' ' '`"
                                local ALLOWTRANSFER=""
                                for ALLOWTRANSFER in $ALLOWTRANSFERS ; do
                                        echo "|ALLOW_TRANSFER| |$ALLOWTRANSFER| || ||">>${dump_temp_file}
                                done
                        fi
                        if [ "$dump_masters" = "yes" ];then
                                local MASTERS="`echo $LINE|grep -Eo "masters[\t ]*{[^}]*}"|grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+[\t ]*;"|tr -s ';' ' '`"
                                local MASTER=""
                                for MASTER in $MASTERS ; do
                                        echo "|MASTER| |$MASTER| || ||">>${dump_temp_file}
                                done
                        fi
                        echo "}" >>${dump_temp_file}
                done
        fi

}

# main
is_root
get_config

# get parameters
if [ $# -eq 1 ]; then
        echo "Using $1 as a dump file\n"
        dump_file="$1"
        dump_temp_file="$dump_file-$$"

fi

if [ $# -gt 1 ]; then
        exit 1
fi

case "$dump" in
        masters)
                get_masters
        ;;
        slaves)
                get_slaves
        ;;
        both)
                get_masters
                get_slaves
        ;;
esac

mv $dump_temp_file $dump_file >>/dev/null 2>&1
echo "`grep -c "{" $dump_file` records processed sucesfully"

exit 0
