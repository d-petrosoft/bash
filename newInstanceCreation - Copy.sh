#!/bin/bash

#***************************************************************************************
# This scrip creates all necessary  files and folder encapsulating  a informix instance 
# and start that instance 
#
# Requirements: 
# 	1. informix installed 
#	2. provided standard  file onconfig.petrosoft.std should be copied to /opt/IBM/informix/etc/. 
#      COPY ONLY ONES SINCE SERVERNUM INCROMENTED IN onconfig.petrosoft.std EVERY TIME
#	3. should be run as root 
# 
# Usage: 
#	newInstanece.sh servername ipAddr portNum
#
# Argument:
#		1. servername -> new name of the server that will be used 
#		2. ipAddr -> ip address of the host 
#		3. portNum -> port number that is not being used by any instance 
########################################################################################


#Check if 3 arguments are passed to the script 
if [ $# -ne 3 ]; then
    echo -e "${RED}illegal number of parameters.\n\t Usage: newInstanece.sh servername ipAddr portNum${NC}"
    exit 1 
fi

################################################################################
# Get passed values
################################################################################
servername=$1
ipAddr=$2
portNum=$3

################################################################################
# Var declaration 
################################################################################

STD_ONCONFIG="/opt/IBM/informix/etc/onconfig.petrosoft.std"
STD_SERVERNAME="petrosoft.std.servername"
STD_LTAPEDEV="petrosoft_ltapedev"
STD_TAPEDEV="petrosoft_tapedev"
STD_ROOTPATH="petrosoft_rootpath"
STD_MSGPATH="petrosoft_msgpath"
RED='\033[0;31m'
NC='\033[0m' # No Color

# vars for files and folders 
rootdir="/mnt/$servername/"
tapedev="/mnt/$servername/backups"
ltapedev="/mnt/$servername/logs"
rootpath="/mnt/$servername/rootdbs"
tmpdbs="/mnt/$servername/tmpdbs"
datadbs="/mnt/$servername/datadbs"
logdbs="/mnt/$servername/logdbs"
msgpath="/mnt/$servername/online.log"

################################################################################
# Validation 	
################################################################################
#Check if it is a root
if [[ $EUID -ne 0 ]]; then
	echo -e  "${RED}This script must be run as root${NC}"
	exit 1
fi

#Check if onconfig.petrosoft.std exits
if [ ! -f /opt/IBM/informix/etc/onconfig.petrosoft.std ]
then
echo -e "${RED}/opt/IBM/informix/etc/onconfig.petrosoft.std does not exist please place the standart file and try again${NC}"
  exit 1
fi

################################################################################
# Add a new host to sqlhosts file
################################################################################
echo "Adding new sqlhosts file ..."
cat > /opt/IBM/informix/etc/sqlhosts.$servername <<- EOM
$servername     onsoctcp        $ipAddr $portNum
EOM
chown informix:informix /opt/IBM/informix/etc/sqlhosts.$servername
echo "Adding new sqlhosts file ... DONE" 

################################################################################
# Add new enviromental variables file
################################################################################
echo "Seting up enviromental variables ..."
if [ ! -d /etc/default/informix_en_vars ]
then
	mkdir /etc/default/informix_en_vars
fi
cat > /etc/default/informix_en_vars/$servername.envar <<- EOM
INFORMIXDIR=/opt/IBM/informix
ONCONFIG=onconfig.$servername
INFORMIXSQLHOSTS=/opt/IBM/informix/etc/sqlhosts.$servername
PATH=$PATH:/opt/IBM/informix/bin
INFORMIXSERVER=$servername
export INFORMIXDIR ONCONFIG PATH INFORMIXSERVER INFORMIXSQLHOSTS
EOM
echo "Seting up enviromental variables ... DONE"

################################################################################
# Create all necesary files 
################################################################################
echo "Creating dbfiles ..."
mkdir $rootdir $tapedev $ltapedev
chmod 755 $rootdir 
chmod 770 $tapedev $ltapedev
touch $logdbs $tmpdbs $datadbs $msgpath $rootpath 
chmod 660 $logdbs $tmpdbs $datadbs $msgpath $rootpath 
chown informix:informix $rootdir
chown informix:informix $rootdir/* -R
echo "Creating dbfiles ... DONE"


################################################################################
# Copy and modify onconfig file 
################################################################################

echo "Editing onconfig file..."
onconfig="/opt/IBM/informix/etc/onconfig.$servername"
cp $STD_ONCONFIG $onconfig
chown informix:informix $onconfig 

sed -i "s/$STD_SERVERNAME/$servername/g" $onconfig
sed -i "s#$STD_LTAPEDEV#$ltapedev#g" $onconfig
sed -i "s#$STD_TAPEDEV#$tapedev#g" $onconfig
sed -i "s#$STD_ROOTPATH#$rootpath#g" $onconfig
sed -i "s#$STD_MSGPATH#$msgpath#g" $onconfig
#incroment SERVERNUM
sed -i "s/SERVERNUM [0-9]*[0-9]/&@/g;:a {s/0@/1/g;s/1@/2/g;s/2@/3/g;s/3@/4/g;s/4@/5/g;s/5@/6/g;s/6@/7/g;s/7@/8/g;s/8@/9/g;s/9@/@0/g;t a};s/@/1/g" $onconfig 
#incroment SERVERNUM in std onconfig for the next time 
sed -i "s/SERVERNUM [0-9]*[0-9]/&@/g;:a {s/0@/1/g;s/1@/2/g;s/2@/3/g;s/3@/4/g;s/4@/5/g;s/5@/6/g;s/6@/7/g;s/7@/8/g;s/8@/9/g;s/9@/@0/g;t a};s/@/1/g" $STD_ONCONFIG 
echo "Editing onconfig file ... DONE"


################################################################################
#Start the instance 
################################################################################
echo "Starting Informix instance ..."
su informix << EOF
. /etc/default/informix_en_vars/$servername.envar
oninit -ivy 
EOF
echo "Starting Informix instance ...DONE"


