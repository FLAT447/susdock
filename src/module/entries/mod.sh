#!/system/bin/sh

# Mod error codes
MOD_ERR_CHECK=1
MOD_ERR_DOWNLOAD=2
MOD_ERR_HASH=3
MOD_ERR_WRITE=4

# Check if update is needed
# Usage: mod_check
# Outputs remote version to stdout if update needed
# Returns 0 if update needed, 1 if up-to-date, >1 on error
mod_check() {
    check_update
    rc=$?

    if [ "$rc" -eq 0 ]; then
        # check_update already resolved the remote tag into $_rv, so there is
        # no need to hit the API a second time.
        # shellcheck disable=SC2154
        echo "$_rv"
        return 0
    fi

    [ "$rc" -eq 1 ] && return 1
    return "$rc"
}

# Download and install update (takes effect after reboot)
# Usage: mod_update
# Returns 0 on success, non-zero on failure
mod_update() {
    _remote=$(get_remote) || return "$MOD_ERR_CHECK"

    # get_remote uses "|" as separator because the sha256 may be empty.
    IFS='|' read -r _ver _sha _url << EOF
$_remote
EOF

    [ -n "$_url" ] || {
        log ERROR "no download URL for this device"
        return "$MOD_ERR_CHECK"
    }

    [ -n "$_sha" ] || {
        log ERROR "no sha256 available from upstream"
        return "$MOD_ERR_HASH"
    }

    mkdir -p "$MOD_DIR" 2> /dev/null || {
        log ERROR "cannot create mod dir: $MOD_DIR"
        return "$MOD_ERR_WRITE"
    }

    download "$_url" "$UPSTREAM_LOCAL_TARGET" || {
        log ERROR "download failed"
        return "$MOD_ERR_DOWNLOAD"
    }

    chmod 644 "$UPSTREAM_LOCAL_TARGET" || {
        log ERROR "cannot chmod $UPSTREAM_LOCAL_TARGET"
        return "$MOD_ERR_WRITE"
    }

    _actual=$(sha256sum "$UPSTREAM_LOCAL_TARGET" 2> /dev/null | awk '{print $1}')
    [ "$_actual" = "$_sha" ] || {
        log ERROR "sha256 mismatch: expected=$_sha actual=$_actual"
        return "$MOD_ERR_HASH"
    }

    echo "$_ver" > "$UPSTREAM_VERSION_FILE" || {
        log ERROR "cannot write version file"
        return "$MOD_ERR_WRITE"
    }

    touch "$REBOOT_FLAG" 2> /dev/null || {
        log ERROR "cannot create reboot flag"
        return "$MOD_ERR_WRITE"
    }

    log INFO "update installed: $_ver (reboot to take effect)"
    return 0
}

# Get local installed version
# Usage: mod_version
# Outputs version to stdout
mod_version() {
    get_local_version
}

# Clear reboot-required marker
# Usage: mod_clear_reboot
# Returns 0 on success, non-zero on failure
mod_clear_reboot() {
    rm -f "$REBOOT_FLAG" || {
        log ERROR "cannot remove reboot flag"
        return 1
    }
    log INFO "reboot flag cleared"
    return 0
}

# Print the effective update source. The setting itself lives in the WebUI
# (localStorage) and reaches the module through UPSTREAM_API / UPSTREAM_MIRROR.
# Usage: mod_upstream
mod_upstream() {
    printf 'upstream=%s\n' "$UPSTREAM_API"
    printf 'mirror=%s\n' "$UPSTREAM_MIRROR"
    printf 'official=%s\n' "$UPSTREAM_API_OFFICIAL"
    return 0
}

# Dispatch mod subcommands
# Usage: mod_dispatch <subcommand> [args...]
mod_dispatch() {
    _sub="${1:-}"
    [ -n "$_sub" ] && shift
    case "$_sub" in
        check) mod_check "$@" ;;
        update) mod_update "$@" ;;
        version) mod_version "$@" ;;
        clear-reboot) mod_clear_reboot "$@" ;;
        upstream) mod_upstream "$@" ;;
        *) err "unknown mod subcommand: ${_sub:-<empty>}" ;;
    esac
}
