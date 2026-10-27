#!/system/bin/sh

MODDIR="${MODDIR:-}"

# MODDIR is set in entry.sh, but we need to ensure it's set here as well
if [[ -z "${MODDIR}" ]]; then
    return 1
fi

DATA_DIR="/data/adb/$(basename "${MODDIR}")"
MOD_DIR="${DATA_DIR}/mod"

# Global Constants

: "LOG"                                                                               #
LOG_LEVEL_ENV="${LOG_LEVEL:-}"                                                        # Level from the environment, wins over the config file
LOG_MAX_BYTES="${LOG_MAX_BYTES:-1048576}"                                             # Maximum log file size, default to 1MB
: "UPSTREAM"                                                                          #
UPSTREAM_REPO="inforcqb/susfs4ksu-lkm"                                                # GitHub repository for upstream releases
UPSTREAM_API_OFFICIAL="https://api.github.com/repos/${UPSTREAM_REPO}/releases/latest" # Official GitHub API for the latest release
UPSTREAM_API_MIRROR_PREFIX="https://ghfast.top/"                                      # Asset accelerator; it cannot proxy the API itself
UPSTREAM_API_ENV="${UPSTREAM_API:-}"                                                  # API URL from the WebUI environment, wins over the default
UPSTREAM_API="${UPSTREAM_API_ENV:-$UPSTREAM_API_OFFICIAL}"                            # Effective API URL
UPSTREAM_MIRROR_ENV="${UPSTREAM_MIRROR:-}"                                            # Asset prefix from the WebUI environment
UPSTREAM_MIRROR=""                                                                    # Effective asset prefix, empty means direct download
UPSTREAM_VERSION_FILE="${MOD_DIR}/version"                                            # File to store the current version of the module
UPSTREAM_LOCAL_TARGET="${MOD_DIR}/susfs_guard_lkm.ko"                                 # Local target file path for the downloaded kernel module
: "SUSFS"                                                                             #
SUSFS_MODULE_NAME="susfs_guard_lkm"                                                   # Kernel module name in lsmod
SUSFS_KSU_SUSFS_BIN="/data/adb/ksu/bin/ksu_susfs"                                     # Path to the ksu_susfs binary
: "REBOOT"                                                                            #
REBOOT_FLAG="${MOD_DIR}/reboot"                                                       # Flag file to indicate that a reboot is required after module update
: "CONFIG"                                                                            #
CONFIG_FILE="${DATA_DIR}/config"                                                      # Persisted settings, written by `log set-level`

# An upstream value must be a plain https URL. It is later handed to curl/wget,
# so reject anything that could change its meaning.
# Usage: _upstream_url_valid <url>
_upstream_url_valid() {
    case "${1:-}" in
        https://?*) ;;
        *) return 1 ;;
    esac

    case "$1" in
        *[[:space:]]*) return 1 ;;
    esac

    case "$1" in
        *['"`$|;&<>()']*) return 1 ;;
    esac

    [ "${#1}" -le 512 ]
}

# Overwrite one key in the config file, keeping every other line intact.
# Usage: config_set <key> <value>
# Returns 0 on success, 1 on failure.
config_set() {
    _key="$1"
    _value="$2"

    mkdir -p "$DATA_DIR" 2> /dev/null || return 1

    _tmp="${CONFIG_FILE}.tmp.$$"
    if [ -f "$CONFIG_FILE" ]; then
        grep -v "^${_key}=" "$CONFIG_FILE" > "$_tmp" 2> /dev/null
    else
        : > "$_tmp"
    fi

    printf '%s=%s\n' "$_key" "$_value" >> "$_tmp" || {
        rm -f "$_tmp"
        return 1
    }

    mv "$_tmp" "$CONFIG_FILE" || {
        rm -f "$_tmp"
        return 1
    }

    return 0
}

# Read the persisted settings. The value is validated, so a hand-edited config
# file cannot change the log level to something unexpected.
_config_load() {
    [ -f "$CONFIG_FILE" ] || return 0
    [ -n "$LOG_LEVEL_ENV" ] && return 0

    _lvl=$(sed -n 's/^LOG_LEVEL=\([A-Za-z]*\)$/\1/p' "$CONFIG_FILE" 2> /dev/null | tail -n 1)
    case "$_lvl" in
        DEBUG | INFO | WARN | ERROR) LOG_LEVEL="$_lvl" ;;
    esac

    return 0
}

_config_load
LOG_LEVEL="${LOG_LEVEL:-INFO}" # Effective log level

# The WebUI passes its own upstream settings through the environment. Validate
# them here: anything that is not a plain https URL falls back to the default.
_upstream_url_valid "$UPSTREAM_API" || UPSTREAM_API="$UPSTREAM_API_OFFICIAL"
if _upstream_url_valid "$UPSTREAM_MIRROR_ENV"; then
    UPSTREAM_MIRROR="$UPSTREAM_MIRROR_ENV"
fi

. "${MODDIR}/lib/log.sh"
. "${MODDIR}/lib/download.sh"
. "${MODDIR}/lib/upstream.sh"
. "${MODDIR}/lib/status.sh"

# End with an explicit success status. Do not use a top-level `return 0` here:
# when following sources, shellcheck treats it as the end of the script and
# flags the caller's subsequent code as unreachable (SC2317).
:
