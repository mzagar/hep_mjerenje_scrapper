#!/bin/bash

### env vars required: HEP_USERNAME, HEP_PASSWORD, HEP_OIB, HEP_OMM (optinally HEP_TOKEN instead username/pass)
### optionally set HEP_OFFLINE to prevent getting current month data from HEP site  

source .config


if [[ "$HEP_TOKEN" == "" && ("$HEP_USERNAME" == "" || "$HEP_PASSWORD" == "") ]]
then
	echo "Missing auth info - specify either HEP_TOKEN or HEP_USERNAME/HEP_PASSWORD."
	exit 1
fi


CURR_MONTH="$(date +%m.%Y)"
MONTH=${1:-"$CURR_MONTH"}
DAY=${2:-"$MONTH"}

HEP_P_FILE="hep_${MONTH}_p.csv"
HEP_R_FILE="hep_${MONTH}_r.csv"

[ "$HEP_DEBUG" != "" ] && echo "Input params: HEP_USERNAME=${HEP_USERNAME}, HEP_PASSWORD=${HEP_PASSWORD}, HEP_TOKEN=${HEP_TOKEN}, HEP_OIB=${HEP_OIB}, HEP_OMM=${HEP_OMM}, CURR_MONTH=${CURR_MONTH}, MONTH=${MONTH}, DAY=${DAY}, HEP_P_FILE=${HEP_P_FILE}, HEP_R_FILE=${HEP_R_FILE}"

# refresh current month file always
if [[ "$MONTH" == "$CURR_MONTH" &&  "$HEP_OFFLINE" == "" ]]
then
	[ "$HEP_DEBUG" != "" ] && echo "Backing up current month files..."
	rm -f $HEP_P_FILE
	rm -f $HEP_R_FILE
fi

if [[ ! -f $HEP_P_FILE || ! -f $HEP_R_FILE ]]
then
	[ "$HEP_DEBUG" != "" ] && echo "Getting data files..."

	if [ "$HEP_TOKEN" == "" ]
	then	
		[ "$HEP_DEBUG" != "" ] && echo "Logging into HEP and getting token..."

		export HEP_TOKEN=$(curl -k -s -H "Content-Type: application/json" https://mjerenje.hep.hr/mjerenja/v1/api/user/login -d "{ \"Username\": \"$HEP_USERNAME\", \"Password\": \"$HEP_PASSWORD\" }" | jq .Token -r)

		[ "$HEP_DEBUG" != "" ] && echo "Acqiured HEP_TOKEN: ${HEP_TOKEN}"
	fi


	# get Produced 'p' month data in a file
	if [ ! -f $HEP_P_FILE ]
	then
		[ "$HEP_DEBUG" != "" ] && echo "Getting HEP P file: ${HEP_P_FILE}"
		curl -s -H "Authorization: Bearer $HEP_TOKEN" https://mjerenje.hep.hr/mjerenja/v1/api/data/file/oib/$HEP_OIB/omm/$HEP_OMM/krivulja/mjesec/$MONTH/smjer/P | jq .data -r | base64 -D > $HEP_P_FILE
	fi
	# get Returned 'r' month data in a file
	if [ ! -f $HEP_R_FILE ]
	then
		[ "$HEP_DEBUG" != "" ] && echo "Getting HEP R file: ${HEP_R_FILE}"
		curl -s -H "Authorization: Bearer $HEP_TOKEN" https://mjerenje.hep.hr/mjerenja/v1/api/data/file/oib/$HEP_OIB/omm/$HEP_OMM/krivulja/mjesec/$MONTH/smjer/R | jq .data -r | base64 -D > $HEP_R_FILE
	fi
fi

# [ "$HEP_DEBUG" != "" ] && echo "Calculating from/to grid numbers..."

# FROM_GRID=$(cat $HEP_P_FILE | grep $DAY | awk '{print $9}' | sed 's/,/./g' | paste -sd+ - | bc)
# TO_GRID=$(cat $HEP_R_FILE | grep $DAY | awk '{print $9}' | sed 's/,/./g' | paste -sd+ - | bc)
# echo "$DAY: $FROM_GRID / $TO_GRID / $(echo "$FROM_GRID-$TO_GRID" | bc)"
