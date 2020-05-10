#!/usr/bin/env bash
#
# Grab images and videos from Instagram
#
#/ Usage:
#/   ./instagrab.sh -u <username>
#/
#/ Options:
#/   -u               required, Instagram username

set -e
set -u

usage() {
    printf "%b\n" "$(grep '^#/' "$0" | cut -c4-)" >&2 && exit 1
}

set_var() {
    _URL="https://www.instagram.com"
    _TIME_STAMP=$(date +%s)
    _SCRIPT_PATH=$(dirname "$0")
}

set_command() {
    _CURL="$(command -v curl)" || command_not_found "curl" "https://curl.haxx.se/download.html"
    _JQ="$(command -v jq)" || command_not_found "jq" "https://stedolan.github.io/jq/download/"
}

set_args() {
    expr "$*" : ".*--help" > /dev/null && usage
    while getopts ":hu:" opt; do
        case $opt in
            u)
                _USER_NAME="$OPTARG"
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

check_var() {
    if [[ -z "${_USER_NAME:-}" ]]; then
        echo '-u <username> is missing!' && usage
    fi
}

download_profile_html() {
    # $1: username
    $_CURL -sS "$_URL/$1/"
}

get_query_hash() {
    # $1: profile html
    local l j
    l=$(grep '/ProfilePageContainer.js' <<< "$1" \
        | grep '<script' \
        | sed -E 's/.*src=//' \
        | awk -F '"' '{print $2}')
    j=$($_CURL -sS "${_URL}${l}")
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

query() {
    # $1: id
    # $2: query hash
    # $3: end cursor positon
    $_CURL -sS "$_URL/graphql/query?query_hash=${2}&variables=%7B%22id%22%3A%22${1}%22%2C%22first%22%3A50%2C%22after%22%3A%22${3}%22%7D"
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

download_content_by_type() {
    # $1: json data, start with "node" under edges
    # $2: output directory
    local n t m
    n=$($_JQ -r '.node.id' <<< "$1")
    t=$($_JQ -r '.node.__typename' <<< "$1")
    if [[ "$t" == "GraphImage" ]]; then
        m=$($_JQ -r '.node.display_url' <<< "$1")
        print_info ">> $t: $m"
        $_CURL -L -g -o "${2}/${n}.jpg" "$m"
    elif [[ "$t" == "GraphVideo" ]]; then
        m=$($_JQ -r '.node.video_url' <<< "$1")
        print_info ">> $t: $m"
        $_CURL -L -g -o "${2}/${n}.mp4" "$m"
    elif [[ "$t" == "GraphSidecar" ]]; then
        local cl
        cl=$($_JQ -r '.node.edge_sidecar_to_children.edges | length' <<< "$1")
        for (( ci = 0; ci < cl; ci++ )); do
            print_info "$t $(( ci+1 ))/$cl"
            m=$($_JQ -r '.node.edge_sidecar_to_children.edges[$i | tonumber]' --arg i "$ci" <<< "$1")
            download_content_by_type "$m" "$2"
        done
    else
        print_warn "Unknow type $t of $n, skip downloading"
    fi
}

main() {
    set_args "$@"
    set_command
    set_var
    check_var

    local page hash data id res postNum reqNum curPos outDir
    page=$(download_profile_html "$_USER_NAME")
    data=$(get_json_data_from_html "$page")
    hash=$(get_query_hash "$page")
    id=$(get_user_id "$data")

    postNum=$(get_post_num "$data")
    reqNum=$((postNum / 50))
    [[ "$((postNum % 50))" -gt "0" ]] && reqNum=$((reqNum + 1))

    print_info "Find $reqNum page(s) to download..."
    outDir="${_SCRIPT_PATH}/${_USER_NAME}-${_TIME_STAMP}"
    mkdir -p "$outDir"
    curPos=""
    reqNum=3
    for (( i = 0; i < reqNum; i++ )); do
        print_info "Downloading $((i+1))/$reqNum..."
        res=$(query "$id" "$hash" "$curPos")
        curPos=$(get_cursor_end_position "$res")
        download_content "$res" "$outDir"
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
