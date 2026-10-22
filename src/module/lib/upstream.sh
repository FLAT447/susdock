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

# Upstream error codes.
# Must stay >1: check_update() uses 1 for "already up-to-date".
US_ERR_HTTP=6
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

# Extract "<url>|<sha256>" for the asset with the exact given name.
# The repository publishes one .ko per Android/kernel pair, so the URL must be
# selected by device fingerprint instead of taking the first asset.
# Usage: _json_asset <file> <name>
_json_asset() {
    awk -v target="$2" '
        function value(line) {
            sub(/^[^:]*:[[:space:]]*"/, "", line)
            sub(/".*$/, "", line)
            return line
        }
        /"name":/ { name = value($0) }
        /"digest":/ {
            digest = ""
            if ($0 ~ /"sha256:/) {
                digest = $0
                sub(/.*"sha256:/, "", digest)
                sub(/".*/, "", digest)
            }
        }
        /"browser_download_url":/ {
            if (name == target)
                print value($0) "|" digest
            name = ""
            digest = ""
        }
    ' "$1"
}

# Fetch release JSON and resolve remote info
# Sets: _RV (version), _RU (matched asset url), _RS (sha256), _RULIST (all urls)
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

    # Asset names look like "susfs_guard_lkm-android14-6.1.ko".
    # Prefer the kernel's GKI branch: a device upgraded to a newer Android
    # release may still run an older kernel branch.
    _av=$(android_kernel_version 2> /dev/null)
    [ -n "$_av" ] || _av=$(android_version 2> /dev/null)
    _av=${_av%%.*}
    _kv=$(kernel_version 2> /dev/null)
    _aname="${SUSFS_MODULE_NAME}-android${_av}-${_kv}.ko"
    _ainfo=$(_json_asset "$_tmp" "$_aname")
    rm -f "$_tmp"

    _RU=${_ainfo%%|*}
    _RS=${_ainfo#*|}

    if [ -z "$_RU" ]; then
        log WARN "no asset for android ${_av:-unknown} / kernel ${_kv:-unknown}: $_aname"
    fi

    log INFO "remote version=$_RV"
    return 0
}

# Compare remote and local version to detect update
# Returns 0 if update needed, 1 if up-to-date, >1 on error
check_update() {
    _rv=$(get_remote_version) || return $?
    _lv=$(get_local_version) || return $?

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

# Get the download URL matching this device
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

# Get remote info as a tuple. "|" is used as the separator because the sha256
# may be empty; space separation would collapse fields during word splitting.
# Usage: get_remote
# Outputs "<version>|<sha256>|<url>" to stdout
get_remote() {
    _us_resolve || return $?
    [ -n "$_RU" ] || return "$US_ERR_PARSE"
    printf '%s|%s|%s\n' "$_RV" "$_RS" "$_RU"
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

    _v=$(tr -d '[:space:]' < "$UPSTREAM_VERSION_FILE" 2> /dev/null)
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
