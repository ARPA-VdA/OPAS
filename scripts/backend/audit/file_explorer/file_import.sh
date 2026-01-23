#!/bin/bash
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#
#   Script Name : file_import.sh
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
# Agencies
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
        arpa_ven )

# server settings
BASE="/home/opas/bin"
SUFFIX_DATA="/builder/import/data"
SUFFIX_CAL="/builder/import/cal"

# Create the CSV file
CSV_DIR="${BASEDIR}/csv/import"
mkdir -p "$CSV_DIR"

# Csv file + header
TS=$(date +"%Y%m%d_%H%M%S")
TS='found'
CSV_FILE="$CSV_DIR/import_${TS}.csv"
echo "data_path,data_type,file_name,file_date,file_location,file_header" > "$CSV_FILE"

# ------------------------------------------------------------------
# PROCESSING FILES
# ------------------------------------------------------------------
# Loop through the agencies array
for arpa in "${ARPAS[@]}"; do
    echo "Processing arpa: $arpa"
    # set the folders
    FOLDERS=("DATA" "CAL")
    for folder in "${FOLDERS[@]}"; do
        if [ "$folder" = "DATA" ]; then
            PATH_ARPA="${BASE}/${arpa}${SUFFIX_DATA}"
        else
            PATH_ARPA="${BASE}/${arpa}${SUFFIX_CAL}"
        fi

        if [ ! -d "$PATH_ARPA" ]; then
            echo "WARNING: Directory not found: $PATH_ARPA"
            continue
        fi

        echo "$folder path: $PATH_ARPA"

        for file in "$PATH_ARPA"/*; do
            # skip if not file
            [[ -f "$file" ]] || continue
            # Extract the extension
            filename=$(basename "$file")
            base="${filename%.*}"
            ext="${filename##*.}"
            # Extract the 'header'
            if [[ "$base" =~ (.*)-([0-9]{4}-[0-9]{2}-[0-9]{2}(-[0-9]{2}-[0-9]{2}-[0-9]{2})?)$ ]]; then
                NAME_PART="${BASH_REMATCH[1]}"

            else
                if [[ "$base" =~ ^(.*)-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12} ]]; then
                    NAME_PART="${BASH_REMATCH[1]}"
                else
                    NAME_PART="$base"
                fi
            fi
            # set data for csv
            data_path="$arpa"
            data_type="$ext"
            file_name="$filename"
            file_location="import"
            file_header="$NAME_PART"
            file_date=$(date -r "$file" +"%Y-%m-%d %H:%M:%S")

            # Write to CSV (quoting fields to handle potential commas in names)
            {
                echo "$data_path,$data_type,$file_name,$file_date,$file_location,$file_header"
            } >> "$CSV_FILE" || echo "ERROR: Impossibile scrivere nel CSV per file $filename"

        done
    done
done

# Run import data script
echo "Importing data"
export CSV_DIR=$CSV_DIR
# run loader
/usr/bin/pgloader --quiet "${BASEDIR}/pg_import.load"

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
