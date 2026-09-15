#!/bin/bash

set -o pipefail

### env vars required: HEP_USERNAME, HEP_PASSWORD, HEP_OIB, HEP_OMM (optionally HEP_TOKEN instead of username/password)
### optionally set HEP_OFFLINE to prevent getting current month data from HEP site

source .config

HEP_API_BASE="${HEP_API_BASE:-https://mjerenje.hep.hr/mjerenja/v1.2/api}"
HEP_SESSION_DIR=""

cleanup() {
    if [[ -n "$HEP_SESSION_DIR" && -d "$HEP_SESSION_DIR" ]]; then
        rm -rf "$HEP_SESSION_DIR"
    fi
}
trap cleanup EXIT

fail() {
    echo "❌ $*" >&2
    exit 1
}

# Smart scraping mode: if no month parameter provided, do intelligent full scraping
if [[ -z "$1" ]]; then
    echo "🔍 Smart scraping mode: ensuring complete data coverage..."

    mkdir -p data/csv

    echo "🚀 Scraping all months from $START_MONTH to current..."
    echo "---"

    # Stop immediately when month generation or any monthly download fails.
    MONTHS=$(bash ./scripts/month_sequence.sh "$START_MONTH") \
        || fail "Could not generate the month sequence."
    while read -r month; do
        [[ -z "$month" ]] && continue
        echo "📅 Processing $month..."
        bash ./scripts/get-hep-data.sh "$month" || fail "Scraping failed for $month"
    done <<< "$MONTHS"

    echo "✅ Smart scraping complete - all data gaps filled"
    exit 0
fi

# Continue with existing single-month logic below...


if [[ -z "$HEP_TOKEN" && (-z "$HEP_USERNAME" || -z "$HEP_PASSWORD") ]]; then
    fail "Missing auth info - specify either HEP_TOKEN or HEP_USERNAME/HEP_PASSWORD."
fi

CURR_MONTH="$(date +%m.%Y)"
MONTH=${1:-"$CURR_MONTH"}
DAY=${2:-"$MONTH"}

HEP_P_FILE="data/csv/hep_${MONTH}_p.csv"
HEP_R_FILE="data/csv/hep_${MONTH}_r.csv"
REFRESH_CURRENT=false
[[ "$MONTH" == "$CURR_MONTH" && -z "$HEP_OFFLINE" ]] && REFRESH_CURRENT=true

[[ -n "$HEP_DEBUG" ]] && echo "Input params: CURR_MONTH=${CURR_MONTH}, MONTH=${MONTH}, DAY=${DAY}"

mkdir -p data/csv

NEED_P=false
NEED_R=false
[[ "$REFRESH_CURRENT" == true || ! -f "$HEP_P_FILE" ]] && NEED_P=true
[[ "$REFRESH_CURRENT" == true || ! -f "$HEP_R_FILE" ]] && NEED_R=true

if [[ "$NEED_P" == true || "$NEED_R" == true ]]; then
    [[ -n "$HEP_OFFLINE" ]] && fail "Offline mode is enabled and data for $MONTH is missing."

    HEP_SESSION_DIR=$(mktemp -d)
    chmod 700 "$HEP_SESSION_DIR"
    COOKIE_JAR="$HEP_SESSION_DIR/cookies"
    AUTH_HEADER="$HEP_SESSION_DIR/auth-header"

    if [[ -n "$HEP_TOKEN" ]]; then
        (umask 077; printf 'Authorization: Bearer %s\n' "$HEP_TOKEN" > "$AUTH_HEADER")
    else
        [[ -n "$HEP_DEBUG" ]] && echo "Logging into HEP API..."
        LOGIN_RESPONSE="$HEP_SESSION_DIR/login.json"
        if ! HEP_USERNAME="$HEP_USERNAME" HEP_PASSWORD="$HEP_PASSWORD" \
            jq -n '{Username: env.HEP_USERNAME, Password: env.HEP_PASSWORD, Token: ""}' | \
            curl --fail --silent --show-error \
                --header "Content-Type: application/json" \
                --request POST \
                --cookie-jar "$COOKIE_JAR" \
                --output "$LOGIN_RESPONSE" \
                --data-binary @- \
                "$HEP_API_BASE/user/login"; then
            fail "HEP login failed."
        fi
        jq -e 'type == "array" and length > 0' "$LOGIN_RESPONSE" >/dev/null \
            || fail "HEP login returned an unexpected response."
    fi

    download_direction() {
        local direction=$1
        local destination=$2
        local content_type
        local auth_options=()

        if [[ -n "$HEP_TOKEN" ]]; then
            auth_options=(--header "@$AUTH_HEADER")
        else
            auth_options=(--cookie "$COOKIE_JAR")
        fi

        [[ -n "$HEP_DEBUG" ]] && echo "Downloading direction $direction for $MONTH..."
        if ! content_type=$(curl --fail --silent --show-error \
            --request POST \
            "${auth_options[@]}" \
            --output "$destination" \
            --write-out '%{content_type}' \
            "$HEP_API_BASE/data/file/oib/$HEP_OIB/omm/$HEP_OMM/krivulja/mjesec/$MONTH/smjer/$direction"); then
            rm -f "$destination"
            fail "HEP data download failed for direction $direction and month $MONTH."
        fi

        [[ -s "$destination" ]] || fail "HEP returned an empty file for direction $direction and month $MONTH."
        case "${content_type,,}" in
            *json*|*html*)
                fail "HEP returned $content_type instead of a data file for direction $direction and month $MONTH."
                ;;
        esac
    }

    if [[ "$NEED_P" == true ]]; then
        download_direction P "$HEP_SESSION_DIR/p.csv"
    fi
    if [[ "$NEED_R" == true ]]; then
        download_direction R "$HEP_SESSION_DIR/r.csv"
    fi

    [[ "$NEED_P" == true ]] && mv "$HEP_SESSION_DIR/p.csv" "$HEP_P_FILE"
    [[ "$NEED_R" == true ]] && mv "$HEP_SESSION_DIR/r.csv" "$HEP_R_FILE"
fi

# [ "$HEP_DEBUG" != "" ] && echo "Calculating from/to grid numbers..."

# FROM_GRID=$(cat $HEP_P_FILE | grep $DAY | awk '{print $9}' | sed 's/,/./g' | paste -sd+ - | bc)
# TO_GRID=$(cat $HEP_R_FILE | grep $DAY | awk '{print $9}' | sed 's/,/./g' | paste -sd+ - | bc)
# echo "$DAY: $FROM_GRID / $TO_GRID / $(echo "$FROM_GRID-$TO_GRID" | bc)"
