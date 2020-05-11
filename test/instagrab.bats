#!/usr/bin/env bats
#
# How to run:
#   ~$ bats test/instagrab.bats

BATS_TEST_SKIPPED=

setup() {
    _SCRIPT="./instagrab.sh"
    _TEST_HTML="test/instagram.html"
    _USER_NAME="test_user"
    _JSON_FROM_HTML=$(cat test/html.json)
    _JSON_FROM_GRAPHQL=$(cat test/graphgl.json)

    _JQ=$(command -v jq)

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

@test "CHECK: get_json_data_from_html()" {
    run get_json_data_from_html "$(cat "$_TEST_HTML")"
    [ "$status" -eq 0 ]
    [ "$output" = "{this is test data here}" ]
}

# [NOT GREAT NOT TERRIBLE] it needs network connection and depend on request
# TODO: need to make local mock
@test "CHECK: get_query_hash()" {
    _URL="https://www.instagram.com"
    _CURL=$(command -v curl)
    run get_query_hash "$(cat "$_TEST_HTML")"
    [ "$status" -eq 0 ]
    [ "$output" = "9dcf6e1a98bc7f6e92953d5a61027b98" ]
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
    _SAVE_JSON_DATA=false
    _CURL=$(command -v echo)
    imgnode="$($_JQ -r '.data.user.edge_owner_to_timeline_media.edges[0]' <<< "$_JSON_FROM_GRAPHQL")"
    run download_content_by_type  "$imgnode" "./test_dir"
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf '%b\n%b' "\033[32m[INFO]\033[0m >> GraphImage: img_url" "-L -g -o ./test_dir/node1.jpg img_url")" ]
}

@test "CHECK: download_content_by_type(): GraphVideo" {
    _SAVE_JSON_DATA=false
    _CURL=$(command -v echo)
    videonode="$($_JQ -r '.data.user.edge_owner_to_timeline_media.edges[1]' <<< "$_JSON_FROM_GRAPHQL")"
    run download_content_by_type  "$videonode" "./test_dir"
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf '%b\n%b' "\033[32m[INFO]\033[0m >> GraphVideo: video_url" "-L -g -o ./test_dir/node2.mp4 video_url")" ]
}

@test "CHECK: download_content_by_type(): GraphSidecar > GraphVideo" {
    _SAVE_JSON_DATA=false
    _CURL=$(command -v echo)
    videonode="$($_JQ -r '.data.user.edge_owner_to_timeline_media.edges[2].node.edge_sidecar_to_children.edges[0]' <<< "$_JSON_FROM_GRAPHQL")"
    run download_content_by_type  "$videonode" "./test_dir2"
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf '%b\n%b' "\033[32m[INFO]\033[0m >> GraphVideo: video_url31" "-L -g -o ./test_dir2/node31.mp4 video_url31")" ]
}

@test "CHECK: download_content_by_type(): GraphSidecar > GraphImage" {
    _SAVE_JSON_DATA=false
    _CURL=$(command -v echo)
    imgnode="$($_JQ -r '.data.user.edge_owner_to_timeline_media.edges[2].node.edge_sidecar_to_children.edges[1]' <<< "$_JSON_FROM_GRAPHQL")"
    run download_content_by_type  "$imgnode" "./test_dir2"
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf '%b\n%b' "\033[32m[INFO]\033[0m >> GraphImage: img_url32" "-L -g -o ./test_dir2/node32.jpg img_url32")" ]
}

@test "CHECK: download_content_by_type(): warning" {
    _SAVE_JSON_DATA=false
    brokennode="$($_JQ -r '.data.user.edge_owner_to_timeline_media.edges[3]' <<< "$_JSON_FROM_GRAPHQL")"
    run download_content_by_type  "$brokennode" "./test_dir3"
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf '%b\n%b' "\033[33m[WARNING]\033[0m Unknown type n/a of node4, skip downloading")" ]
}

@test "CHECK: download_content_by_type(): save json data" {
    _SAVE_JSON_DATA=true
    _CURL=$(command -v echo)
    _DATA_DIR=$(mktemp -d)
    imgnode="$($_JQ -r '.data.user.edge_owner_to_timeline_media.edges[2].node.edge_sidecar_to_children.edges[1]' <<< "$_JSON_FROM_GRAPHQL")"
    run download_content_by_type  "$imgnode" "./test_dir2"
    [ "$status" -eq 0 ]
    [ "$(md5sum $_DATA_DIR/node32.json | awk '{print $1}')" = "c2981123d055bd697f3c99bb1ee1edf3" ]
    [ "$output" = "$(printf '%b\n%b' "\033[32m[INFO]\033[0m >> GraphImage: img_url32" "-L -g -o ./test_dir2/node32.jpg img_url32")" ]
}

@test "CHECK: download_content()" {
    download_content_by_type() {
        echo "$1" "$2" >&2
    }
    node1="$($_JQ -r '.data.user.edge_owner_to_timeline_media.edges[0]' <<< "$_JSON_FROM_GRAPHQL")"
    node2="$($_JQ -r '.data.user.edge_owner_to_timeline_media.edges[1]' <<< "$_JSON_FROM_GRAPHQL")"
    node3="$($_JQ -r '.data.user.edge_owner_to_timeline_media.edges[2]' <<< "$_JSON_FROM_GRAPHQL")"
    node4="$($_JQ -r '.data.user.edge_owner_to_timeline_media.edges[3]' <<< "$_JSON_FROM_GRAPHQL")"
    run download_content "$_JSON_FROM_GRAPHQL" "./test_dir4"
    [ "$status" -eq 0 ]
    [ "$output" == "$(printf '%b ./test_dir4\n%b ./test_dir4\n%b ./test_dir4\n%b ./test_dir4' "$node1" "$node2" "$node3" "$node4")" ]
}
