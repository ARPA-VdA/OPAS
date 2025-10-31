#!/bin/bash
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#
#   Script Name : import-data.sh
#        Author : Ecometer s.n.c.
#          Date : 2025-03-31
#
#   Download data from SFTP server
#
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

#--------------------------------------------------------
# crontab
#--------------------------------------------------------
# # import remote data
# 2,4,8,32,34 * * * * ~/bin/arpa_xxxxx/builder/import-data.sh >> ~/bin/arpa_xxxxx/builder/log/data_$(date +\%Y\%m\%d).log 2>&1

#--------------------------------------------------------
# lock dir/file
#--------------------------------------------------------
BASEDIR=$(dirname $0)
SCRIPTFILE=$(basename $0)
LOCKFILE="${BASEDIR}/${SCRIPTFILE}.pid"
#echo $LOCKFILE

echo
echo "Running script -> $SCRIPTFILE @ `date`"
echo "Lockfile -> $LOCKFILE"

# script already running check
if [ -e $LOCKFILE ] && kill -0 `cat $LOCKFILE`
then
    echo "$SCRIPTFILE already running. Aborting."
    exit
fi
trap "rm -fv $LOCKFILE; exit" INT TERM EXIT
echo $$ > $LOCKFILE

# local paths
# TODAY=$(date +%Y%m%d)
# YEAR=$(date +%Y)
# MONTH=$(date +%m)
# DOWNLOADDIR="${BASEDIR}/import"
# BACKUPDIR="${BASEDIR}/imported/$YEAR/$MONTH"
# # create local path if not exists
# echo "Create local path if not exists"
# [ -d $DOWNLOADDIR ] || mkdir -p $DOWNLOADDIR
# [ -d $BACKUPDIR ] || mkdir -p $BACKUPDIR

#--------------------------------------------------------
# sftp settings - https://lftp.yar.ru/lftp-man.html
#--------------------------------------------------------
URL="sftp.xxxxx.it:22"
USER="arpa.xxxxx"
PASS="xxxxxxxxxx"
REGEX="*.dat"

#--------------------------------------------------------
# download data files
#--------------------------------------------------------
LOCAL_DIR="${BASEDIR}/import/data"
REMOTE_DIR="/arpa.xxxxx/data"
echo "Download files from $REMOTE_DIR"
lftp sftp://$USER:$PASS@$URL << EOF
    cd $REMOTE_DIR
    lcd $LOCAL_DIR
    mirror --verbose --ascii --file=$REGEX --Remove-source-files -c
EOF

#--------------------------------------------------------
# check
#--------------------------------------------------------
if [ ! $? -eq 0 ]; then
    echo "Cant download files. Make sure the credentials and server information are correct"
else
    echo "Result ok, launching import"
fi

#--------------------------------------------------------
# run import data script
#--------------------------------------------------------
/home/opas/perl5/perlbrew/perls/perl-5.38.0/bin/perl "${BASEDIR}/import-data.pl"

#--------------------------------------------------------
# end restore
#--------------------------------------------------------
echo "Done."
