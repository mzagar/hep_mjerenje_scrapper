#!/bin/bash

### env vars required: HEP_USERNAME, HEP_PASSWORD, HEP_OIB, HEP_OMM (optinally HEP_TOKEN instead username/pass)
### optionally set HEP_OFFLINE to prevent getting current month data from HEP site

source .config

# Smart scraping mode: if no month parameter provided, do intelligent full scraping
if [[ -z "$1" ]]; then
    echo "🔍 Smart scraping mode: ensuring complete data coverage..."

    # Find latest month from existing CSV files (chronological sort)
    LATEST_MONTH=$(ls hep_*_p.csv 2>/dev/null | \
        sed 's/hep_\([0-9][0-9]\)\.\([0-9][0-9][0-9][0-9]\)_p\.csv/\2.\1/' | \
        sort | tail -1 | \
        sed 's/\([0-9][0-9][0-9][0-9]\)\.\([0-9][0-9]\)/\2.\1/')

    # Delete latest month files if any exist to ensure completeness
    if [[ -n "$LATEST_MONTH" ]]; then
        echo "📂 Found latest month: $LATEST_MONTH"
        echo "🗑️  Deleting files to ensure completeness..."
        rm -f hep_${LATEST_MONTH}_*.csv
        echo "✅ Deleted hep_${LATEST_MONTH}_p.csv and hep_${LATEST_MONTH}_r.csv"
    else
        echo "📂 No existing CSV files found - fresh start"
    fi

    echo "🚀 Scraping all months from $START_MONTH to current..."
    echo "---"

    # Scrape all months from START_MONTH to current
    for month in $(bash ./scripts/month_sequence.sh ${START_MONTH}); do
        echo "📅 Processing $month..."
        bash ./scripts/get-hep-data.sh $month
    done

    echo "✅ Smart scraping complete - all data gaps filled"
    exit 0
fi

# Continue with existing single-month logic below...


if [[ "$HEP_TOKEN" == "" && ("$HEP_USERNAME" == "" || "$HEP_PASSWORD" == "") ]]
then
	echo "Missing auth info - specify either HEP_TOKEN or HEP_USERNAME/HEP_PASSWORD."
	exit 1
fi


CURR_MONTH="$(date +%m.%Y)"
MONTH=${1:-"$CURR_MONTH"}
DAY=${2:-"$MONTH"}

HEP_P_FILE="data/csv/hep_${MONTH}_p.csv"
HEP_R_FILE="data/csv/hep_${MONTH}_r.csv"

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
