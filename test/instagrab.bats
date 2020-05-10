#!/usr/bin/env bats
#
# How to run:
#   ~$ bats test/instagrab.bats

BATS_TEST_SKIPPED=

setup() {
    _SCRIPT="./instagrab.sh"
    _TEST_HTML="test/instagram.html"
    _USER_NAME="test_user"
    _JSON_FROM_HTML='{"entry_data":{"ProfilePage":[{"graphql":{"user":{"id":"test_id","edge_owner_to_timeline_media":{"count":42}}}}]}}'
    _JSON_FROM_GRAPHQL='{"data":{"user":{"id":"test_id","edge_owner_to_timeline_media":{"count":42,"page_info":{"end_cursor":"endcursorpos"},"edges":[{"node":{"id":"node1","__typename":"GraphImage","display_url":"img_url"}},{"node":{"id":"node2","__typename":"GraphVideo","video_url":"video_url"}},{"node":{"id":"node3","__typename":"GraphSidecar"}}]}}}}'

    _JQ=$(command -v jq)

    source $_SCRIPT
}

teardown() {
    echo "cleanup"
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
    _CURL=$(command -v echo)
    imgnode="$($_JQ -r '.data.user.edge_owner_to_timeline_media.edges[0]' <<< "$_JSON_FROM_GRAPHQL")"
    run download_content_by_type  "$imgnode" "./test_dir"
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf '%b\n%b' "\033[32m[INFO]\033[0m >> GraphImage: img_url" "-L -g -o ./test_dir/node1.jpg img_url")" ]
}

@test "CHECK: download_content_by_type(): GraphVideo" {
    _CURL=$(command -v echo)
    videonode="$($_JQ -r '.data.user.edge_owner_to_timeline_media.edges[1]' <<< "$_JSON_FROM_GRAPHQL")"
    run download_content_by_type  "$videonode" "./test_dir"
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf '%b\n%b' "\033[32m[INFO]\033[0m >> GraphVideo: video_url" "-L -g -o ./test_dir/node2.mp4 video_url")" ]
}
