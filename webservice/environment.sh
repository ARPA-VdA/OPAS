#!/bin/bash
#
# run this script: source environment.sh
#

# fail on uninitialized vars rather than treating them as null
#set -u
# fail on the first program that returns $? != 0
#set -e
# tab
tabs 2
# colors
NORMAL=$(tput sgr0)
BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)

# Read env variables
clear
echo
echo ">>> Setting web service environment <<<"
echo "Checking .env file..."
if [ -f .env ]
then
    echo "Export variables..."
    #export $(cat .env | xargs)
    export $(grep -v '^#' .env | xargs)
else
    echo "Missing '.env' file!" && exit
fi

# api call
echo "Api call to get tokens..."
API_RES=$(
    curl -s -d '{"email":"'$USER'", "password":"'$PASS'"}' \
    -H "Content-Type: application/json" \
    -X POST $ENDPOINT/login
)
TOKEN=$(jq -r '.token' <<<"$API_RES")
REFRESH_TOKEN=$(jq -r '.refreshToken' <<<"$API_RES")

# tokens
export TOKEN
export REFRESH_TOKEN

# print
printf "Info...\n"
printf "\t${BLUE}endpoint:${GREEN} $ENDPOINT ${NORMAL}\n"
printf "\t${BLUE}user:${GREEN} $USER ${NORMAL}\n"
printf "\t${BLUE}password:${GREEN} $PASS ${NORMAL}\n"
printf "\t${BLUE}token:${GREEN} $TOKEN ${NORMAL}\n"
printf "\t${BLUE}refresh token:${GREEN} $REFRESH_TOKEN ${NORMAL}\n"

# test ws
echo "Api test..."
curl -s $ENDPOINT/ | jq

echo "All done."