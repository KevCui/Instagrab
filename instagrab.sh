#!/usr/bin/env bash
#
# Grab images and videos and more from Instagram
#
#/ Usage:
#/   ./instagrab.sh -u <username> [-d] [-i] [-v] [-f <yyyymmdd>] [-t <yyyymmdd>]
#/
#/ Options:
#/   -u               required, Instagram username
#/   -d               optional, skip json data download
#/   -i               optional, skip image download
#/   -v               optional, skip video download
#/   -f <yyyymmdd>    optional, from date, format yyyymmdd
#/   -t <yyyymmdd>    optional, to date, format yyyymmdd

set -e
set -u

usage() {
    printf "%b\n" "$(grep '^#/' "$0" | cut -c4-)" >&2 && exit 1
}

set_var() {
    _URL="https://www.instagram.com"
    _SCRIPT_PATH=$(dirname "$0")
    _TIME_STAMP=$(date +%s)
    _OUT_DIR="${_SCRIPT_PATH}/${_USER_NAME}_${_TIME_STAMP}"
    _DATA_DIR="$_OUT_DIR/data"

    if [[ "$_SKIP_JSON_DATA" == true ]]; then
        mkdir -p "$_OUT_DIR"
    else
        mkdir -p "$_DATA_DIR"
    fi

    if [[ -z "${_FROM_DATE:-}" ]]; then
        _FROM_DATE_UNIXTIME=$(date +%s -d "20100101")
    else
        _FROM_DATE_UNIXTIME=$(date +%s -d "$_FROM_DATE")
    fi
    if [[ -z "${_TO_DATE:-}" ]]; then
        _TO_DATE_UNIXTIME="$_TIME_STAMP"
    else
        _TO_DATE_UNIXTIME=$(date +%s -d "$_TO_DATE")
    fi
}

set_command() {
    _CURL="$(command -v curl)" || command_not_found "curl" "https://curl.haxx.se/download.html"
    _JQ="$(command -v jq)" || command_not_found "jq" "https://stedolan.github.io/jq/download/"
}

set_args() {
    expr "$*" : ".*--help" > /dev/null && usage
    _SKIP_JSON_DATA=false
    _SKIP_IMAGE=false
    _SKIP_VIDEO=false
    while getopts ":hdivu:f:t:" opt; do
        case $opt in
            u)
                _USER_NAME="$OPTARG"
                ;;
            d)
                _SKIP_JSON_DATA=true
                ;;
            i)
                _SKIP_IMAGE=true
                ;;
            v)
                _SKIP_VIDEO=true
                ;;
            f)
                _FROM_DATE="$OPTARG"
                ;;
            t)
                _TO_DATE="$OPTARG"
                ;;
            h)
                usage
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                usage
                ;;
        esac
    done
}

print_info() {
    # $1: info message
    printf "%b\n" "\033[32m[INFO]\033[0m $1" >&2
}

print_warn() {
    # $1: warning message
    printf "%b\n" "\033[33m[WARNING]\033[0m $1" >&2
}

print_error() {
    # $1: error message
    printf "%b\n" "\033[31m[ERROR]\033[0m $1" >&2
    exit 1
}

command_not_found() {
    # $1: command name
    # $2: installation URL
    if [[ -n "${2:-}" ]]; then
        print_error "$1 command not found! Install from $2"
    else
        print_error "$1 command not found!"
    fi
}

check_arg() {
    if [[ -z "${_USER_NAME:-}" ]]; then
        print_error "-u <username> is missing!"
    fi

    if [[ -n "${_FROM_DATE:-}" ]]; then
        if [[ (! "$_FROM_DATE" =~ ^[[:digit:]]{8}$) ]]; then
            print_error "-f $_FROM_DATE, wrong date format, must be yyyymmdd!"
        else
            date +%s -d "$_FROM_DATE" > /dev/null
        fi
    fi

    if [[ -n "${_TO_DATE:-}" ]]; then
        date +%s -d "$_TO_DATE" >/dev/null 2>&1 || true
        if [[ (! "$_TO_DATE" =~ ^[[:digit:]]{8}$) ]]; then
            print_error "-t $_TO_DATE, wrong date format, must be yyyymmdd!"
        else
            date +%s -d "$_TO_DATE" > /dev/null
        fi
    fi

    if [[ -n "${_FROM_DATE:-}"  && -n "${_TO_DATE:-}" ]]; then
        if [[ $(compare_time "$_FROM_DATE" "$_TO_DATE") == ">" ]]; then
            print_error "-t ${_TO_DATE} is earlier than -f ${_FROM_DATE}!"
        fi
    fi
}

run_curl() {
    # $1: URL
    $_CURL -sS "$1"
}

get_query_hash() {
    # $1: profile html
    local l j
    l=$(grep '/ProfilePageContainer.js' <<< "$1" \
        | grep '<script' \
        | sed -E 's/.*src=//' \
        | awk -F '"' '{print $2}')
    j=$(run_curl "${_URL}${l}")
    grep "queryId" <<< "$j" \
        | grep "edge_owner_to_timeline_media" \
        | sed -E 's/.*queryId//' \
        | awk -F '"' '{print $2}'
}

get_json_data_from_html() {
    # $1: profile html
    grep 'window._sharedData =' <<< "$1" \
        | sed -E 's/.*sharedData = //;s/;$//' \
        | sed -E 's/;<\/script>//'
}

get_user_id() {
    # $1: json data from html
    $_JQ -r '.entry_data.ProfilePage[].graphql.user.id' <<< "$1"
}

get_post_num() {
    # $1: json data from html
    $_JQ -r '.entry_data.ProfilePage[].graphql.user.edge_owner_to_timeline_media.count' <<< "$1"
}

get_cursor_end_position() {
    # $1: json data from graphql
    $_JQ -r '.data.user.edge_owner_to_timeline_media.page_info.end_cursor' <<< "$1"
}

download_content() {
    # $1: json data from graphql
    # $2: output directory
    local l j
    l=$($_JQ -r '.data.user.edge_owner_to_timeline_media.edges | length' <<< "$1")
    for (( di = 0; di < l; di++ )); do
        j=$($_JQ -r '.data.user.edge_owner_to_timeline_media.edges[$i | tonumber]' --arg i "$di" <<< "$1")
        download_content_by_type "$j" "$2"
    done
}

compare_time() {
    # $1: timestamp/date 1
    # $2: timestamp/date 2
    if [[ "$1" -eq "$2" ]]; then
        echo "="
    elif [[ "$1" -gt "$2" ]]; then
        echo ">"
    elif [[ "$1" -lt "$2" ]]; then
        echo "<"
    fi
}

download_content_by_type() {
    # $1: json data, start with "node" under edges
    # $2: output directory
    local n t m ts
    n=$($_JQ -r '.node.id' <<< "$1")
    t=$($_JQ -r '.node.__typename' <<< "$1")
    ts=$($_JQ -r '.node.taken_at_timestamp' <<< "$1")
    [[ "$ts" == "null" ]] && ts="$_FROM_DATE_UNIXTIME"

    if [[ $(compare_time "$ts" "$_FROM_DATE_UNIXTIME") != "<" && $(compare_time "$ts" "$_TO_DATE_UNIXTIME") != ">" ]]; then
        [[ "$_SKIP_JSON_DATA" == false && "$n" != "" ]] && $_JQ -r <<< "$1" > "$_DATA_DIR/${n}.json"
        if [[ "$t" == "GraphImage" ]]; then
            if [[ "$_SKIP_IMAGE" == true ]]; then
                print_info "Skip image download"
            else
                m=$($_JQ -r '.node.display_url' <<< "$1")
                print_info ">> $t: $m"
                $_CURL -L -g -o "${2}/${n}.jpg" "$m"
            fi
        elif [[ "$t" == "GraphVideo" ]]; then
            if [[ "$_SKIP_VIDEO" == true ]]; then
                print_info "Skip video download"
            else
                m=$($_JQ -r '.node.video_url' <<< "$1")
                print_info ">> $t: $m"
                $_CURL -L -g -o "${2}/${n}.mp4" "$m"
            fi
        elif [[ "$t" == "GraphSidecar" ]]; then
            local cl
            cl=$($_JQ -r '.node.edge_sidecar_to_children.edges | length' <<< "$1")
            for (( ci = 0; ci < cl; ci++ )); do
                print_info "$t $(( ci+1 ))/$cl"
                m=$($_JQ -r '.node.edge_sidecar_to_children.edges[$i | tonumber]' --arg i "$ci" <<< "$1")
                download_content_by_type "$m" "$2"
            done
        else
            print_warn "Skip download: unknown type $t of $n"
        fi
    else
        if [[ $(compare_time "$ts" "$_FROM_DATE_UNIXTIME") == "<" ]]; then
            print_info "Skip further download: media are published earlier than ${_FROM_DATE_UNIXTIME}"
            exit 0
        fi
        print_info "Skip download: media isn't published in the time period ${_FROM_DATE_UNIXTIME}-${_TO_DATE_UNIXTIME}"
    fi
}

main() {
    set_args "$@"
    check_arg
    set_command
    set_var

    local page hash data id res postNum reqNum curPos
    page=$(run_curl "$_URL/$_USER_NAME/")
    data=$(get_json_data_from_html "$page")
    hash=$(get_query_hash "$page")
    id=$(get_user_id "$data")

    [[ "$_SKIP_JSON_DATA" == false ]] && $_JQ -r <<< "$data" > "$_DATA_DIR/data.json"

    postNum=$(get_post_num "$data")
    reqNum=$((postNum / 50))
    [[ "$((postNum % 50))" -gt "0" ]] && reqNum=$((reqNum + 1))

    print_info "Find $postNum post(s), $reqNum page(s)"
    curPos=""
    for (( i = 0; i < reqNum; i++ )); do
        print_info "Checking $((i+1))/$reqNum..."
        res=$(run_curl "$_URL/graphql/query?query_hash=${hash}&variables=%7B%22id%22%3A%22${id}%22%2C%22first%22%3A50%2C%22after%22%3A%22${curPos}%22%7D")
        curPos=$(get_cursor_end_position "$res")
        download_content "$res" "$_OUT_DIR"
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
