#!/system/bin/sh

# Check if susfs module is loaded
# Usage: status_installed
# Outputs "true" or "false" to stdout
# Returns 0 if loaded, 1 if not loaded
status_installed() {
    if susfs_installed; then
        echo "true"
        return 0
    fi
    echo "false"
    return 1
}

# Get running susfs version
# Usage: status_susfs_version
# Outputs version to stdout
status_susfs_version() {
    susfs_version
}

# Check if reboot is required
# Usage: status_reboot_required
# Outputs "true" or "false" to stdout
# Returns 0 if reboot required, 1 if not
status_reboot_required() {
    if [ -f "$REBOOT_FLAG" ]; then
        echo "true"
        return 0
    fi
    echo "false"
    return 1
}

# Get local-only summary info. No network access, so this is cheap enough to
# call on every UI refresh.
# Usage: status_quick
# Outputs key=value lines to stdout
status_quick() {
    _st_android=$(android_version 2> /dev/null || echo "unknown")
    _st_kernel=$(kernel_version 2> /dev/null || echo "unknown")
    # GKI 分支来自 uname 的 -androidNN- 标记，选择上游资产时优先用它
    _st_gki=$(android_kernel_version 2> /dev/null || echo "")

    if susfs_installed; then
        _st_loaded="true"
    else
        _st_loaded="false"
    fi

    if [ -f "$REBOOT_FLAG" ]; then
        _st_reboot="true"
    else
        _st_reboot="false"
    fi

    _st_running=$(susfs_version 2> /dev/null || echo "unknown")
    _st_local=$(get_local_version 2> /dev/null || echo "unknown")

    _st_size=0
    if [ -f "$UPSTREAM_LOCAL_TARGET" ]; then
        _st_size=$(wc -c < "$UPSTREAM_LOCAL_TARGET" 2> /dev/null | tr -d '[:space:]')
    fi
    [ -n "$_st_size" ] || _st_size=0

    echo "android_version=$_st_android"
    echo "kernel_version=$_st_kernel"
    echo "gki_branch=$_st_gki"
    echo "loaded=$_st_loaded"
    echo "reboot_required=$_st_reboot"
    echo "running_version=$_st_running"
    echo "local_version=$_st_local"
    echo "ko_size=$_st_size"
    return 0
}

# Dispatch status subcommands
# Usage: status_dispatch <subcommand> [args...]
status_dispatch() {
    _sub="${1:-}"
    [ -n "$_sub" ] && shift
    case "$_sub" in
        installed) status_installed "$@" ;;
        susfs_version) status_susfs_version "$@" ;;
        reboot_required) status_reboot_required "$@" ;;
        quick) status_quick "$@" ;;
        *) err "unknown status subcommand: ${_sub:-<empty>}" ;;
    esac
}
