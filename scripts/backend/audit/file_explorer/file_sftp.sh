#!/bin/bash
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#
#   Script Name : file_sftp.sh
#        Author : Ecometer s.n.c.
#          Date : 2025-12-30
#
#   Search files on SFTP server
#
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

# version
VERSION=0.1.0

# Lock dir/file
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

# ------------------------------------------------------------------
# CONFIG
# ------------------------------------------------------------------
# Agencies
declare -A arpa1=(  [user]="---" [pwd]="---" [path]="appa.tn"     )
declare -A arpa2=(  [user]="---" [pwd]="---" [path]="appa.bz"     )
declare -A arpa3=(  [user]="---" [pwd]="---" [path]="arpa.vda"    )
declare -A arpa4=(  [user]="---" [pwd]="---" [path]="arpa.cam"    )
declare -A arpa5=(  [user]="---" [pwd]="---" [path]="arpa.pu"     )
declare -A arpa6=(  [user]="---" [pwd]="---" [path]="arpa.umbria" )
declare -A arpa7=(  [user]="---" [pwd]="---" [path]="arpa.er"     )
declare -A arpa8=(  [user]="---" [pwd]="---" [path]="arpa.fvg"    )
declare -A arpa9=(  [user]="---" [pwd]="---" [path]="arpa.to"     )
declare -A arpa10=( [user]="---" [pwd]="---" [path]="arpa.laz"    )
declare -A arpa11=( [user]="---" [pwd]="---" [path]="arpa.lig"    )
declare -A arpa12=( [user]="---" [pwd]="---" [path]="arpa.ven"    )
declare -A arpa13=( [user]="---" [pwd]="---" [path]="arpa.abr"    )
declare -A arpa14=( [user]="---" [pwd]="---" [path]="arpa.mar"    )

# Create an indexed array containing the NAMES of the hashes
ARPAS=(arpa1 arpa2 arpa3 arpa4 arpa5 arpa6 arpa7 arpa8 arpa9 arpa11 arpa12 arpa13 arpa14)

# Create the CSV file
CSV_DIR="${BASEDIR}/csv/import"
mkdir -p "$CSV_DIR"

# Csv file + header
TS=$(date +"%Y%m%d_%H%M%S")
TS='found'
CSV_FILE="$CSV_DIR/sftp_${TS}.csv"
echo "data_path,data_type,file_name,file_date,file_location,file_header" > "$CSV_FILE"

# ------------------------------------------------------------------
# PROCESSING FILES FROM SFTP
# ------------------------------------------------------------------

# Loop through the indexed array
echo "Loop through the indexed array"
for arpa_alias in "${ARPAS[@]}"; do

    # Use 'local -n' to create a nameref (a pointer) to the hash
    declare -n u="$arpa_alias"

    # Print info
    echo "Name: ${u[user]}, Password: ${u[pwd]}, Path: ${u[path]}"

    # Get remote files
    echo "Get remote file list"
    file_list=$(lftp -c "
        set net:timeout 10;
        set net:max-retries 2;
        set sftp:connect-program 'ssh -a -x -o ConnectTimeout=10';
        open -u ${u[user]},${u[pwd]} sftp://$SFTP_URL/${u[path]}/data;
        cls -1F --date --time-style=\"+%Y-%m-%d %H:%M:%S\";
    ")
    if [ $? -ne 0 ]; then
        echo "Error: Connection timed out or failed."
        # exit 1
    fi

    # Print file list
    echo "$file_list"

    # Process the variable line by line
    echo "Process the variable line by line"

    # Format expected: YYYY-MM-DD HH:MM:SS filename
    while read -r f_date f_time f_name; do

        # Skip empty lines
        [[ -z "$f_name" ]] && continue

        # Extract the 'header'
        if [[ "$f_name" =~ (.*)-([0-9]{4}-[0-9]{2}-[0-9]{2}(-[0-9]{2}-[0-9]{2}-[0-9]{2})?)$ ]]; then
            NAME_PART="${BASH_REMATCH[1]}"
        else
            if [[ "$f_name" =~ ^(.*)-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12} ]]; then
                NAME_PART="${BASH_REMATCH[1]}"
            else
                NAME_PART="$f_name"
            fi
        fi

        # Write to CSV (quoting fields to handle potential commas in names)
        {
            echo "${u[user]},dat,$NAME_PART,$f_date $f_time,sftp,$file_header"
        } >> "$CSV_FILE" || echo "ERROR: CSV writing on $filename"
    done <<< "$file_list"

    echo ""
done

# Run import data script
echo "Importing data"
export CSV_DIR=$CSV_DIR
# run loader
/usr/bin/pgloader --quiet "${BASEDIR}/pg_sftp.load"

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
