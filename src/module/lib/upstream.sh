#!/system/bin/sh

# Required variables from common.sh
[ -n "${UPSTREAM_REPO:-}" ] || {
    log ERROR "UPSTREAM_REPO not defined"
    return 1
}
[ -n "${UPSTREAM_API:-}" ] || {
    log ERROR "UPSTREAM_API not defined"
    return 1
}
[ -n "${UPSTREAM_VERSION_FILE:-}" ] || {
    log ERROR "UPSTREAM_VERSION_FILE not defined"
    return 1
}
[ -n "${UPSTREAM_LOCAL_TARGET:-}" ] || {
    log ERROR "UPSTREAM_LOCAL_TARGET not defined"
    return 1
}

# Upstream error codes
US_ERR_HTTP=1
US_ERR_PARSE=2
US_ERR_NOFILE=3
US_ERR_HASH=4
US_ERR_LOCAL=5

# Extract first string value by key from a JSON file
# Usage: _json_get <file> <key>
_json_get() {
    grep -m1 "\"$2\"" "$1" 2> /dev/null \
        | sed -E 's/^[^:]*:[[:space:]]*"([^"]*)".*/\1/'
}

# Extract all browser_download_url values from a JSON file
# Usage: _json_urls <file>
_json_urls() {
    grep '"browser_download_url"' "$1" 2> /dev/null \
        | sed -E 's/^[^:]*:[[:space:]]*"([^"]*)".*/\1/'
}

# Fetch release JSON and resolve remote info
# Sets: _RV (version), _RU (main url), _RS (sha256), _RULIST (all urls)
_us_resolve() {
    _tmp=$(mktemp)
    download "$UPSTREAM_API" "$_tmp" || {
        log ERROR "failed to fetch release info"
        rm -f "$_tmp"
        return "$US_ERR_HTTP"
    }

    _RV=$(_json_get "$_tmp" "tag_name")
    [ -n "$_RV" ] || {
        log ERROR "cannot parse tag_name"
        rm -f "$_tmp"
        return "$US_ERR_PARSE"
    }

    _RULIST=$(_json_urls "$_tmp")
    _RU=$(echo "$_RULIST" | head -1)

    _cu=$(echo "$_RULIST" | grep -i 'checksums\|sha256' | head -1)
    rm -f "$_tmp"

    _RS=""
    if [ -n "$_cu" ]; then
        _ctmp=$(mktemp)
        if download "$_cu" "$_ctmp"; then
            _aname=$(basename "$_RU")
            _RS=$(grep -m1 "$_aname" "$_ctmp" 2> /dev/null | awk '{print $1}')
        fi
        rm -f "$_ctmp"
    fi

    log INFO "remote version=$_RV"
    return 0
}

# Compare remote and local version to detect update
# Returns 0 if update needed, 1 if up-to-date, >1 on error
check_update() {
    _rv=$(get_remote_version) || return "$US_ERR_HTTP"
    _lv=$(get_local_version) || return "$US_ERR_LOCAL"

    if [ "$_rv" = "$_lv" ]; then
        log INFO "up-to-date ($_lv)"
        return 1
    fi

    log INFO "update available: $_lv -> $_rv"
    return 0
}

# Get remote latest version tag
# Usage: get_remote_version
# Outputs version to stdout
get_remote_version() {
    _us_resolve || return $?
    echo "$_RV"
    return 0
}

# Get remote latest sha256
# Usage: get_remote_sha256sum
# Outputs sha256 to stdout
get_remote_sha256sum() {
    _us_resolve || return $?
    [ -n "$_RS" ] || {
        log ERROR "no sha256 available"
        return "$US_ERR_HASH"
    }
    echo "$_RS"
    return 0
}

# Get remote main package download URL (first asset)
# Usage: get_remote_url
# Outputs url to stdout
get_remote_url() {
    _us_resolve || return $?
    [ -n "$_RU" ] || {
        log ERROR "no download URL available"
        return "$US_ERR_PARSE"
    }
    echo "$_RU"
    return 0
}

# Get all remote download URLs (one per line)
# Usage: get_remote_urls
# Outputs urls to stdout, one per line
get_remote_urls() {
    _us_resolve || return $?
    [ -n "$_RULIST" ] || {
        log ERROR "no download URLs available"
        return "$US_ERR_PARSE"
    }
    echo "$_RULIST"
    return 0
}

# Get remote info as a tuple
# Usage: get_remote
# Outputs "<version> <sha256> <url>" to stdout
get_remote() {
    _us_resolve || return $?
    echo "$_RV $_RS $_RU"
    return 0
}

# Get local version from config file
# Usage: get_local_version
# Outputs version to stdout
get_local_version() {
    [ -f "$UPSTREAM_VERSION_FILE" ] || {
        log ERROR "local version file not found: $UPSTREAM_VERSION_FILE"
        return "$US_ERR_NOFILE"
    }

    _v=$(cat "$UPSTREAM_VERSION_FILE" 2> /dev/null | tr -d '[:space:]')
    [ -n "$_v" ] || {
        log ERROR "local version file is empty"
        return "$US_ERR_NOFILE"
    }

    echo "$_v"
    return 0
}

# Get local file sha256
# Usage: get_local_sha256sum
# Outputs sha256 to stdout
get_local_sha256sum() {
    [ -f "$UPSTREAM_LOCAL_TARGET" ] || {
        log ERROR "local file not found: $UPSTREAM_LOCAL_TARGET"
        return "$US_ERR_NOFILE"
    }

    sha256sum "$UPSTREAM_LOCAL_TARGET" 2> /dev/null | awk '{print $1}'
    return 0
}

# Get local info as a tuple
# Usage: get_local
# Outputs "<version> <sha256>" to stdout
get_local() {
    _lv=$(get_local_version) || return $?
    _ls=$(get_local_sha256sum) || return $?

    echo "$_lv $_ls"
    return 0
}
