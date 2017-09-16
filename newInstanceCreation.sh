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
# Var declarations 
################################################################################

# STANDART VARS 
STD_ONCONFIG="/opt/IBM/informix/etc/onconfig.petrosoft.std"
## Dbspace sizes 
PLOGDBS_SIZE="100000"
LOGDBS_SIZE="200000"
TMPDBS_SIZE="100000"
CDRDBS_SIZE="200000"
QDATADBS_SIZE="200000"
DATADBS_SIZE="1000000"
SBDBS_SIZE="2000000"

RED='\033[0;31m'
NC='\033[0m' # No Color

# vars for files and folders 
rootdir="/mnt/$servername/"
tapedev="$rootdir/backups"
ltapedev="$rootdir/logs"
rootpath="$rootdir/rootdbs"
tmpdbs="$rootdir/tmpdbs"
datadbs="$rootdir/datadbs"
logdbs="$rootdir/logdbs"
msgpath="$rootdir/online.log"
cdrdbs="$rootdir/cdrdbs"
sbdbs="$rootdir/sbdbs"
qdatadbs="$rootdir/qdatadbs"
plogdbs="$rootdir/plogdbs"
tmpdbs="$rootdir/tmpdbs" 


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
# Create all necesary files with privileges
################################################################################
echo "Creating dbfiles ..."
mkdir $rootdir $tapedev $ltapedev
chmod 755 $rootdir 
chmod 770 $tapedev $ltapedev
touch $logdbs $tmpdbs $datadbs $msgpath $rootpath $cdrdbs $sbdbs $qdatadbs $plogdbs $tmpdbs
chmod 660 $logdbs $tmpdbs $datadbs $msgpath $rootpath $cdrdbs $sbdbs $qdatadbs $plogdbs $tmpdbs
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

# Change necesary config values 
sed -i "s#^DBSERVERNAME.*/DBSERVERNAME $servername#g" $onconfig
sed -i "s#^TAPEDEV.*/TAPEDEV $tapedev#g" $onconfig
sed -i "s#^LTAPEDEV.*/LTAPEDEV $ltapedev#g" $onconfig
sed -i "s#^ROOTPATH.*/ROOTPATH $rootpath#g" $onconfig
sed -i "s#^MSGPATH.*/MSGPATH $msgpath#g" $onconfig

#incroment SERVERNUM
sed -i "s/SERVERNUM [0-9]*[0-9]/&@/g;:a {s/0@/1/g;s/1@/2/g;s/2@/3/g;s/3@/4/g;s/4@/5/g;s/5@/6/g;s/6@/7/g;s/7@/8/g;s/8@/9/g;s/9@/@0/g;t a};s/@/1/g" $onconfig 
#incroment SERVERNUM in std onconfig for the next time 
sed -i "s/SERVERNUM [0-9]*[0-9]/&@/g;:a {s/0@/1/g;s/1@/2/g;s/2@/3/g;s/3@/4/g;s/4@/5/g;s/5@/6/g;s/6@/7/g;s/7@/8/g;s/8@/9/g;s/9@/@0/g;t a};s/@/1/g" $STD_ONCONFIG 
echo "Editing onconfig file ... DONE"


################################################################################
# Start a new instance 
################################################################################
echo "Starting Informix instance ..."
su informix << EOF
. /etc/default/informix_en_vars/$servername.envar
oninit -ivy
onspaces -c -P plogdbs -p $plogdbs -o 0 -s $PLOGDBS_SIZE -u
onspaces -c -d logdbs -p $logdbs -o 0 -s $LOGDBS_SIZE -u
onspaces -c -t -d tmpdbs -p $tmpdbs -o 0 -s $TMPDBS_SIZE -u
onspaces -c -d cdrdbs -p $cdrdbs -o 0 -s $CDRDBS_SIZE -u
onspaces -c -S qdatadbs -p $qdatadbs -o 0 -s $QDATADBS_SIZE -u
onspaces -c -d datadbs -p $datadbs -o 0 -s $DATADBS_SIZE
onspaces -c -S sbdbs -p $sbdbs -o 0 -s $SBDBS_SIZE
EOF
echo "Starting Informix instance ...DONE"


