#!/usr/bin/env bats
#
# How to run:
#   ~$ bats test/instagrab.bats

BATS_TEST_SKIPPED=

setup() {
    _SCRIPT="./instagrab.sh"
    _TEST_HTML="test/instagram.html"
    _TEST_JS="test/test.js"
    _USER_NAME="test_user"
    _JSON_FROM_HTML=$(cat test/html.json)
    _JSON_FROM_GRAPHQL=$(cat test/graphgl.json)
    _SKIP_JSON_DATA=true
    _SKIP_IMAGE=false
    _SKIP_VIDEO=false
    _FROM_DATE_UNIXTIME="11111010"
    _TO_DATE_UNIXTIME="22221010"

    _JQ=$(command -v jq)
    _CURL=$(command -v echo)

    source $_SCRIPT
}

@test "CHECK: print_info()" {
    run print_info "this is an INFO"
    [ "$status" -eq 0 ]
    [ "$output" = "[32m[INFO][0m this is an INFO" ]
}

@test "CHECK: print_warn()" {
    run print_warn "this is a WARNING"
    [ "$status" -eq 0 ]
    [ "$output" = "[33m[WARNING][0m this is a WARNING" ]
}

@test "CHECK: print_error()" {
    run print_error "this is an ERROR"
    [ "$status" -eq 1 ]
    [ "$output" = "[31m[ERROR][0m this is an ERROR" ]
}

@test "CHECK: command_not_found()" {
    run command_not_found "bats"
    [ "$status" -eq 1 ]
    [ "$output" = "[31m[ERROR][0m bats command not found!" ]
}

@test "CHECK: command_not_found(): show where-to-install" {
    run command_not_found "bats" "batsland"
    [ "$status" -eq 1 ]
    [ "$output" = "[31m[ERROR][0m bats command not found! Install from batsland" ]
}

@test "CHECK: check_arg(): all mandatory variables are set" {
    run check_arg
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "CHECK: check_arg(): no \$_USER_NAME" {
    unset _USER_NAME
    run check_arg
    [ "$status" -eq 1 ]
    [ "$output" = "$(printf '%b\n' "\033[31m[ERROR]\033[0m -u <username> is missing!")" ]
}

@test "CHECK: check_arg(): wrong format \$_FROM_DATE" {
    _FROM_DATE="20201a1b"
    run check_arg
    [ "$status" -eq 1 ]
    [ "$output" = "$(printf '%b\n' "\033[31m[ERROR]\033[0m -f $_FROM_DATE, wrong date format, must be yyyymmdd!")" ]
}

@test "CHECK: check_arg(): wrong date \$_FROM_DATE" {
    _FROM_DATE="20203030"
    run check_arg
    [ "$output" = "date: invalid date ‘"$_FROM_DATE"’" ]
}

@test "CHECK: check_arg(): wrong format \$_TO_DATE" {
    _TO_DATE="20201a1b"
    run check_arg
    [ "$status" -eq 1 ]
    [ "$output" = "$(printf '%b\n' "\033[31m[ERROR]\033[0m -t $_TO_DATE, wrong date format, must be yyyymmdd!")" ]
}

@test "CHECK: check_arg(): wrong date \$_TO_DATE" {
    _TO_DATE="20203030"
    run check_arg
    [ "$output" = "date: invalid date ‘"$_TO_DATE"’" ]
}

@test "CHECK: check_arg(): pass \$_FROM_DATE < \$_TO_DATE" {
    _FROM_DATE="10101010"
    _TO_DATE="20201010"
    run check_arg
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "CHECK: check_arg(): pass \$_FROM_DATE = \$_TO_DATE" {
    _FROM_DATE="10101010"
    _TO_DATE="10101010"
    run check_arg
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "CHECK: check_arg(): fail \$_FROM_DATE > \$_TO_DATE" {
    _FROM_DATE="20201010"
    _TO_DATE="10101010"
    run check_arg
    [ "$status" -eq 1 ]
    [ "$output" = "$(printf '%b\n' "\033[31m[ERROR]\033[0m -t ${_TO_DATE} is earlier than -f ${_FROM_DATE}!")" ]
}

@test "CHECK: get_json_data_from_html()" {
    run get_json_data_from_html "$(cat "$_TEST_HTML")"
    [ "$status" -eq 0 ]
    [ "$output" = "{this is test data here}" ]
}

@test "CHECK: get_query_hash()" {
    run_curl() {
        echo "$1" >&2
        cat "$_TEST_JS"
    }
    _URL="testurl"
    run get_query_hash "$(cat "$_TEST_HTML")"
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf '%b\n%b' "testurl/static/bundles/metro/ProfilePageContainer.js/test.js" "thisisatesthash")" ]
}

@test "CHECK: get_user_id()" {
    run get_user_id "$_JSON_FROM_HTML"
    [ "$status" -eq 0 ]
    [ "$output" = "test_id" ]
}

@test "CHECK: get_post_num()" {
    run get_post_num "$_JSON_FROM_HTML"
    [ "$status" -eq 0 ]
    [ "$output" = "42" ]
}

@test "CHECK: get_cursor_end_position()" {
    run get_cursor_end_position "$_JSON_FROM_GRAPHQL"
    [ "$status" -eq 0 ]
    [ "$output" = "endcursorpos" ]
}

@test "CHECK: download_content_by_type(): GraphImage" {
    imgnode="$($_JQ -r '.data.user.edge_owner_to_timeline_media.edges[0]' <<< "$_JSON_FROM_GRAPHQL")"
    run download_content_by_type  "$imgnode" "./test_dir"
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf '%b\n%b' "\033[32m[INFO]\033[0m >> GraphImage: img_url" "-L -g -o ./test_dir/node1.jpg img_url")" ]
}

@test "CHECK: download_content_by_type(): GraphImage skipped" {
    _SKIP_IMAGE=true
    imgnode="$($_JQ -r '.data.user.edge_owner_to_timeline_media.edges[0]' <<< "$_JSON_FROM_GRAPHQL")"
    run download_content_by_type  "$imgnode" "./test_dir"
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf '%b\n' "\033[32m[INFO]\033[0m Skip image download")" ]
}

@test "CHECK: download_content_by_type(): GraphVideo" {
    videonode="$($_JQ -r '.data.user.edge_owner_to_timeline_media.edges[1]' <<< "$_JSON_FROM_GRAPHQL")"
    run download_content_by_type  "$videonode" "./test_dir"
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf '%b\n%b' "\033[32m[INFO]\033[0m >> GraphVideo: video_url" "-L -g -o ./test_dir/node2.mp4 video_url")" ]
}

@test "CHECK: download_content_by_type(): GraphVideo skipped" {
    _SKIP_VIDEO=true
    videonode="$($_JQ -r '.data.user.edge_owner_to_timeline_media.edges[1]' <<< "$_JSON_FROM_GRAPHQL")"
    run download_content_by_type  "$videonode" "./test_dir"
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf '%b\n' "\033[32m[INFO]\033[0m Skip video download")" ]
}

@test "CHECK: download_content_by_type(): GraphSidecar > GraphVideo" {
    videonode="$($_JQ -r '.data.user.edge_owner_to_timeline_media.edges[2].node.edge_sidecar_to_children.edges[0]' <<< "$_JSON_FROM_GRAPHQL")"
    run download_content_by_type  "$videonode" "./test_dir2"
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf '%b\n%b' "\033[32m[INFO]\033[0m >> GraphVideo: video_url31" "-L -g -o ./test_dir2/node31.mp4 video_url31")" ]
}

@test "CHECK: download_content_by_type(): GraphSidecar > GraphImage" {
    imgnode="$($_JQ -r '.data.user.edge_owner_to_timeline_media.edges[2].node.edge_sidecar_to_children.edges[1]' <<< "$_JSON_FROM_GRAPHQL")"
    run download_content_by_type  "$imgnode" "./test_dir2"
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf '%b\n%b' "\033[32m[INFO]\033[0m >> GraphImage: img_url32" "-L -g -o ./test_dir2/node32.jpg img_url32")" ]
}

@test "CHECK: download_content_by_type(): warning" {
    brokennode="$($_JQ -r '.data.user.edge_owner_to_timeline_media.edges[3]' <<< "$_JSON_FROM_GRAPHQL")"
    run download_content_by_type  "$brokennode" "./test_dir3"
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf '%b\n%b' "\033[33m[WARNING]\033[0m Skip download: unknown type n/a of node4")" ]
}

@test "CHECK: download_content_by_type(): save json data" {
    _SKIP_JSON_DATA=false
    _DATA_DIR=$(mktemp -d)
    imgnode="$($_JQ -r '.data.user.edge_owner_to_timeline_media.edges[2].node.edge_sidecar_to_children.edges[1]' <<< "$_JSON_FROM_GRAPHQL")"
    run download_content_by_type  "$imgnode" "./test_dir2"
    [ "$status" -eq 0 ]
    [ "$(md5sum $_DATA_DIR/node32.json | awk '{print $1}')" = "c2981123d055bd697f3c99bb1ee1edf3" ]
    [ "$output" = "$(printf '%b\n%b' "\033[32m[INFO]\033[0m >> GraphImage: img_url32" "-L -g -o ./test_dir2/node32.jpg img_url32")" ]
}

@test "CHECK: download_content_by_type(): taken date < \$_FROM_DATE_UNIXTIME" {
    node="$($_JQ -r '.data.user.edge_owner_to_timeline_media.edges[4]' <<< "$_JSON_FROM_GRAPHQL")"
    run download_content_by_type "$node" "./test_dir3"
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf '%b\n' "\033[32m[INFO]\033[0m Skip further download: media are published earlier than ${_FROM_DATE_UNIXTIME}")" ]
}

@test "CHECK: download_content_by_type(): taken date > \$_TO_DATE_UNIXTIME" {
    node="$($_JQ -r '.data.user.edge_owner_to_timeline_media.edges[5]' <<< "$_JSON_FROM_GRAPHQL")"
    run download_content_by_type "$node" "./test_dir3"
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf '%b\n' "\033[32m[INFO]\033[0m Skip download: media isn't published in the time period ${_FROM_DATE_UNIXTIME}-${_TO_DATE_UNIXTIME}")" ]
}

@test "CHECK: download_content()" {
    download_content_by_type() {
        echo "$1" "$2" >&2
    }
    node1="$($_JQ -r '.data.user.edge_owner_to_timeline_media.edges[0]' <<< "$_JSON_FROM_GRAPHQL")"
    node2="$($_JQ -r '.data.user.edge_owner_to_timeline_media.edges[1]' <<< "$_JSON_FROM_GRAPHQL")"
    node3="$($_JQ -r '.data.user.edge_owner_to_timeline_media.edges[2]' <<< "$_JSON_FROM_GRAPHQL")"
    node4="$($_JQ -r '.data.user.edge_owner_to_timeline_media.edges[3]' <<< "$_JSON_FROM_GRAPHQL")"
    node5="$($_JQ -r '.data.user.edge_owner_to_timeline_media.edges[4]' <<< "$_JSON_FROM_GRAPHQL")"
    node6="$($_JQ -r '.data.user.edge_owner_to_timeline_media.edges[5]' <<< "$_JSON_FROM_GRAPHQL")"
    run download_content "$_JSON_FROM_GRAPHQL" "./test_dir4"
    [ "$status" -eq 0 ]
    [ "$output" == "$(printf '%b ./test_dir4\n%b ./test_dir4\n%b ./test_dir4\n%b ./test_dir4\n%b ./test_dir4\n%b ./test_dir4' "$node1" "$node2" "$node3" "$node4" "$node5" "$node6")" ]
}

@test "CHECK: compare_time(): =" {
    run compare_time "1" "1"
    [ "$status" -eq 0 ]
    [ "$output" == "=" ]
}

@test "CHECK: compare_time(): >" {
    run compare_time "2" "1"
    [ "$status" -eq 0 ]
    [ "$output" == ">" ]
}

@test "CHECK: compare_time(): <" {
    run compare_time "2" "3"
    [ "$status" -eq 0 ]
    [ "$output" == "<" ]
}

@test "CHECK: compare_time(): empty value" {
    run compare_time "" "4"
    [ "$status" -eq 0 ]
    [ "$output" == "<" ]
}
