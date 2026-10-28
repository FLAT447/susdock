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
    _android=$(android_version 2> /dev/null || echo "unknown")
    _kernel=$(kernel_version 2> /dev/null || echo "unknown")

    if susfs_installed; then
        _loaded="true"
    else
        _loaded="false"
    fi

    if [ -f "$REBOOT_FLAG" ]; then
        _reboot="true"
    else
        _reboot="false"
    fi

    _running=$(susfs_version 2> /dev/null || echo "unknown")
    _local=$(get_local_version 2> /dev/null || echo "unknown")

    _size=0
    if [ -f "$UPSTREAM_LOCAL_TARGET" ]; then
        _size=$(wc -c < "$UPSTREAM_LOCAL_TARGET" 2> /dev/null | tr -d '[:space:]')
    fi
    [ -n "$_size" ] || _size=0

    echo "android_version=$_android"
    echo "kernel_version=$_kernel"
    echo "loaded=$_loaded"
    echo "reboot_required=$_reboot"
    echo "running_version=$_running"
    echo "local_version=$_local"
    echo "ko_size=$_size"
    return 0
}

# Get summary info including the remote version. This performs a network
# request, so it can take a while on a slow connection.
# Usage: status_info
# Outputs key=value lines to stdout
status_info() {
    status_quick

    _remote=$(get_remote_version 2> /dev/null || echo "unknown")
    echo "remote_version=$_remote"
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
        info) status_info "$@" ;;
        *) err "unknown status subcommand: ${_sub:-<empty>}" ;;
    esac
}
