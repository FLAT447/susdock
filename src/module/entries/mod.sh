#!/system/bin/sh

# Mod error codes
MOD_ERR_CHECK=1
MOD_ERR_DOWNLOAD=2
MOD_ERR_HASH=3
MOD_ERR_WRITE=4

# Download and install an update (takes effect after reboot).
# The WebUI parses the release JSON and passes the exact asset here, so the
# shell never has to understand JSON.
# Usage: mod_update <version> <url> <sha256>
# Returns 0 on success, non-zero on failure
mod_update() {
    _up_ver="${1:-}"
    _up_url="${2:-}"
    _up_sha="${3:-}"

    [ -n "$_up_ver" ] && [ -n "$_up_url" ] && [ -n "$_up_sha" ] || {
        log ERROR "usage: mod update <version> <url> <sha256>"
        return "$MOD_ERR_CHECK"
    }

    case "$_up_url" in
        https://?*) ;;
        *)
            log ERROR "invalid download url: $_up_url"
            return "$MOD_ERR_CHECK"
            ;;
    esac

    # Accept upper case from callers, compare in lower case like sha256sum.
    _up_sha=$(printf '%s' "$_up_sha" | tr '[:upper:]' '[:lower:]')
    case "$_up_sha" in
        *[!0-9a-f]*)
            log ERROR "invalid sha256"
            return "$MOD_ERR_HASH"
            ;;
    esac
    [ "${#_up_sha}" -eq 64 ] || {
        log ERROR "invalid sha256"
        return "$MOD_ERR_HASH"
    }

    mkdir -p "$MOD_DIR" 2> /dev/null || {
        log ERROR "cannot create mod dir: $MOD_DIR"
        return "$MOD_ERR_WRITE"
    }

    download "$_up_url" "$UPSTREAM_LOCAL_TARGET" || {
        log ERROR "download failed"
        return "$MOD_ERR_DOWNLOAD"
    }

    chmod 644 "$UPSTREAM_LOCAL_TARGET" || {
        log ERROR "cannot chmod $UPSTREAM_LOCAL_TARGET"
        return "$MOD_ERR_WRITE"
    }

    _up_actual=$(sha256sum "$UPSTREAM_LOCAL_TARGET" 2> /dev/null | awk '{print $1}')
    [ "$_up_actual" = "$_up_sha" ] || {
        log ERROR "sha256 mismatch: expected=$_up_sha actual=$_up_actual"
        return "$MOD_ERR_HASH"
    }

    echo "$_up_ver" > "$UPSTREAM_VERSION_FILE" || {
        log ERROR "cannot write version file"
        return "$MOD_ERR_WRITE"
    }

    touch "$REBOOT_FLAG" 2> /dev/null || {
        log ERROR "cannot create reboot flag"
        return "$MOD_ERR_WRITE"
    }

    # 开关开启时同步副本，否则 post-fs-data.d 里还是上一版脚本。
    # 失败只记一条警告：驱动已经装好，不能因此让更新整体失败。
    if autoload_enabled; then
        autoload_enable || log WARN "failed to refresh autoload script"
    fi

    log INFO "update installed: $_up_ver (reboot to take effect)"
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

# Toggle boot-time autoload. With no argument, print the current state.
# Usage: mod_autoload [on|off]
mod_autoload() {
    _mode="${1:-}"

    case "$_mode" in
        "")
            if autoload_enabled; then
                echo "enabled=true"
            else
                echo "enabled=false"
            fi
            return 0
            ;;
        on)
            autoload_enable || return "$MOD_ERR_WRITE"
            echo "enabled=true"
            return 0
            ;;
        off)
            autoload_disable || return "$MOD_ERR_WRITE"
            echo "enabled=false"
            return 0
            ;;
        *)
            log ERROR "invalid autoload mode: $_mode"
            return 1
            ;;
    esac
}

# Dispatch mod subcommands
# Usage: mod_dispatch <subcommand> [args...]
mod_dispatch() {
    _sub="${1:-}"
    [ -n "$_sub" ] && shift
    case "$_sub" in
        release) release_json "$@" ;;
        update) mod_update "$@" ;;
        version) mod_version "$@" ;;
        clear-reboot) mod_clear_reboot "$@" ;;
        upstream) mod_upstream "$@" ;;
        autoload) mod_autoload "$@" ;;
        *) err "unknown mod subcommand: ${_sub:-<empty>}" ;;
    esac
}
