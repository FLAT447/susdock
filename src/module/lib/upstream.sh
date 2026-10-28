#!/system/bin/sh

# Required variables from common.sh
[ -n "${UPSTREAM_API:-}" ] || {
    log ERROR "UPSTREAM_API not defined"
    return 1
}
[ -n "${UPSTREAM_VERSION_FILE:-}" ] || {
    log ERROR "UPSTREAM_VERSION_FILE not defined"
    return 1
}

# Upstream error codes.
US_ERR_HTTP=6
US_ERR_NOFILE=3

# Download the release JSON and print it verbatim.
# The WebUI parses it with JSON.parse. Keeping the shell out of the JSON
# avoids the fragile grep/awk parsing this module used to do: minified
# bodies, error pages and SELinux read failures all looked like
# "cannot parse tag_name".
# Usage: release_json
release_json() {
    # Do not name this _tmp: download() reuses _tmp for its own scratch file
    # and would overwrite the path before cat runs.
    _json_file="${DATA_DIR}/release.$$.json"
    mkdir -p "$DATA_DIR" 2> /dev/null

    download "$UPSTREAM_API" "$_json_file" || {
        log ERROR "failed to fetch release info"
        rm -f "$_json_file"
        return "$US_ERR_HTTP"
    }

    cat "$_json_file"
    _rc=$?
    rm -f "$_json_file"
    return "$_rc"
}

# Get local version from config file
# Usage: get_local_version
# Outputs version to stdout
get_local_version() {
    [ -f "$UPSTREAM_VERSION_FILE" ] || {
        log ERROR "local version file not found: $UPSTREAM_VERSION_FILE"
        return "$US_ERR_NOFILE"
    }

    _v=$(tr -d '[:space:]' < "$UPSTREAM_VERSION_FILE" 2> /dev/null)
    [ -n "$_v" ] || {
        log ERROR "local version file is empty"
        return "$US_ERR_NOFILE"
    }

    echo "$_v"
    return 0
}
