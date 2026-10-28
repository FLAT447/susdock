#!/system/bin/sh

# Status error codes
ST_ERR_TOOL=1
ST_ERR_VERSION=2

# Check if susfs module is loaded via lsmod
# Usage: susfs_installed
# Returns 0 if loaded, 1 if not loaded, >1 on error
susfs_installed() {
    command -v lsmod > /dev/null 2>&1 || {
        log ERROR "lsmod not available"
        return "$ST_ERR_TOOL"
    }

    lsmod | grep -q "^${SUSFS_MODULE_NAME} " && return 0
    return 1
}

# Get running susfs version from ksu_susfs
# Usage: susfs_version
# Outputs version to stdout, e.g. "1.5.2"
# Returns 0 on success, non-zero on failure
susfs_version() {
    [ -x "$SUSFS_KSU_SUSFS_BIN" ] || {
        log ERROR "ksu_susfs not found: $SUSFS_KSU_SUSFS_BIN"
        return "$ST_ERR_TOOL"
    }

    _sv_raw=$("$SUSFS_KSU_SUSFS_BIN" show version 2> /dev/null)
    [ -n "$_sv_raw" ] || {
        log ERROR "failed to get susfs version"
        return "$ST_ERR_VERSION"
    }

    echo "${_sv_raw#v}"
    return 0
}

# Get the GKI branch from the kernel release string
# Usage: android_kernel_version
# Outputs e.g. "14" for "6.6.30-android14-11-g...", empty if absent
android_kernel_version() {
    uname -r 2> /dev/null | sed -n 's/.*-android\([0-9][0-9]*\)-.*/\1/p'
}

# Get Android version string
# Usage: android_version
# Outputs version to stdout, e.g. "13"
# Returns 0 on success, non-zero on failure
android_version() {
    command -v getprop > /dev/null 2>&1 || {
        log ERROR "getprop not available"
        return "$ST_ERR_TOOL"
    }

    _av_ver=$(getprop ro.build.version.release 2> /dev/null)
    [ -n "$_av_ver" ] || {
        log ERROR "failed to get android version"
        return "$ST_ERR_VERSION"
    }

    echo "$_av_ver"
    return 0
}

# Get kernel major version
# Usage: kernel_version
# Outputs major version to stdout, e.g. "5.15"
# Returns 0 on success, non-zero on failure
kernel_version() {
    command -v uname > /dev/null 2>&1 || {
        log ERROR "uname not available"
        return "$ST_ERR_TOOL"
    }

    _kv_raw=$(uname -r 2> /dev/null)
    [ -n "$_kv_raw" ] || {
        log ERROR "failed to get kernel version"
        return "$ST_ERR_VERSION"
    }

    # "5.15.77-perf" -> "5.15"
    echo "$_kv_raw" | awk -F. '{print $1"."$2}'
    return 0
}
