#!/bin/bash
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#
#   Script Name : file_backup.sh
#        Author : Ecometer s.n.c.
#          Date : 2025-12-30
#
#   Search files on SCRIPT server
#
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

# version
VERSION=1.0

# ------------------------------------------------------------------
#  SCRIPT LOCK
# ------------------------------------------------------------------
# lock dir/file
BASEDIR=$(dirname $0)
SCRIPTFILE=$(basename $0)
LOCKFILE="${BASEDIR}/${SCRIPTFILE}.pid"

echo
echo "Running script -> $SCRIPTFILE @ `date`"
# script already running check
if [ -e $LOCKFILE ] && kill -0 `cat $LOCKFILE`
then
    echo "$SCRIPTFILE already running. Aborting."
    exit
fi
trap "rm -fv $LOCKFILE; exit" INT TERM EXIT
echo $$ > $LOCKFILE

# Read config file
source "${BASEDIR}/secrets.conf"

set -euo pipefail
shopt -s nullglob

# ------------------------------------------------------------------
# CONFIG
# ------------------------------------------------------------------
ARPAS=( appa_blz
        appa_trn
        arpa_abr
        arpa_bas
        arpa_cal
        arpa_cam
        arpa_emr
        arpa_fvg
        arpa_laz
        arpa_lig
        arpa_lom
        arpa_mar
        arpa_mol
        arpa_pie
        arpa_pug
        arpa_sar
        arpa_sic
        arpa_tos
        arpa_umb
        arpa_vda
        arpa_ven
)

# server settings
BASE="/home/opas/bin"
SUFFIX="/builder/backup"

# Create the CSV file
CSV_DIR="${BASEDIR}/csv/import"
mkdir -p "$CSV_DIR"

# Csv file + header
TS=$(date +"%Y%m%d_%H%M%S")
TS='found'
CSV_FILE="$CSV_DIR/backup_${TS}.csv"
echo "data_path,data_type,file_name,file_date,file_location,file_header" > "$CSV_FILE"

# ------------------------------------------------------------------
# PROCESSING FILES
# ------------------------------------------------------------------
# Date calc
YESTERDAY=$(date -d "yesterday" +"%Y-%m-%d")
YESTERDAY_YEAR=$(date -d "yesterday" +"%Y")
YESTERDAY_MONTH=$(date -d "yesterday" +"%m")
TODAY_YEAR=$(date +"%Y")
TODAY_MONTH=$(date +"%m")

# ------------------------------------------------------------------
# PROCESSING FILES
# ------------------------------------------------------------------
# Loop through the agencies array
for arpa in "${ARPAS[@]}"; do
    echo "Processing arpa: $arpa"
    # set the folders
    for VAR_DIR in "${BASE}/${arpa}${SUFFIX}"/*; do
        [ -d "$VAR_DIR" ] || continue

        # If on month change parse two different paths
        if [[ "$TODAY_YEAR" -eq "$YESTERDAY_YEAR" && "$TODAY_MONTH" -eq "$YESTERDAY_MONTH" ]]; then
            PATHS_TO_CHECK=("$VAR_DIR/$TODAY_YEAR/$TODAY_MONTH")
        else
            PATHS_TO_CHECK=("$VAR_DIR/$YESTERDAY_YEAR/$YESTERDAY_MONTH" "$VAR_DIR/$TODAY_YEAR/$TODAY_MONTH")
        fi

        for PATH_ARPA in "${PATHS_TO_CHECK[@]}"; do
            [ -d "$PATH_ARPA" ] || continue
            echo "Processing folder: $PATH_ARPA"

            # File for yesterday and today
            find "$PATH_ARPA" -maxdepth 1 -type f -newermt "$YESTERDAY 00:00:00" ! -newermt "now" | while read -r file; do
                # Extract the extension
                filename=$(basename "$file")
                base="${filename%.*}"
                ext="${filename##*.}"
                IFS="-" read -r -a PARTS <<< "$base"
                len=${#PARTS[@]}
                # set data for csv
                data_path="$arpa"
                data_type="$ext"
                file_name="$filename"
                file_location="backup"
                file_header=$(basename "$(dirname "$(dirname "$(dirname "$file")")")")
                file_date=$(date -r "$file" +"%Y-%m-%d %H:%M:%S")

                # Write to CSV (quoting fields to handle potential commas in names)
                {
                    echo "$data_path,$data_type,$file_name,$file_date,$file_location,$file_header"
                } >> "$CSV_FILE" || echo "ERROR: Impossibile scrivere nel CSV per file $filename"

            done
        done
    done
done


# Run import data script
echo "Importing data"
export CSV_DIR=$CSV_DIR
# run loader
/usr/bin/pgloader --quiet "${BASEDIR}/pg_backup.load"

# check exit code
OUT=$?
# echo "exit status: $OUT"
if [ $OUT -ne 0 ]; then
    echo "ERROR!"
fi

# Remove file
#rm -f $CSV_FILE

# End script
echo "Done. CSV generated: $CSV_FILE"
exit 0
