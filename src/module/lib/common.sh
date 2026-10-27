#!/system/bin/sh

MODDIR="${MODDIR:-}"

# MODDIR is set in entry.sh, but we need to ensure it's set here as well
if [ -z "$MODDIR" ]; then
    return 1
fi

DATA_DIR="/data/adb/$(basename "$MODDIR")"
MOD_DIR="$DATA_DIR/mod"

# Global Constants

:"LOG"                                                                     #
LOG_LEVEL="${LOG_LEVEL:-INFO}"                                             # Log level
LOG_MAX_BYTES="${LOG_MAX_BYTES:-1048576}"                                  # Maximum log file size, default to 1MB
:"UPSTREAM"                                                                #
UPSTREAM_REPO="inforcqb/susfs4ksu-lkm"                                     # GitHub repository for upstream releases
UPSTREAM_API="https://api.github.com/repos/$UPSTREAM_REPO/releases/latest" # GitHub API URL for latest release
UPSTREAM_VERSION_FILE="$MOD_DIR/version"                                   # File to store the current version of the module
UPSTREAM_LOCAL_TARGET="$MOD_DIR/susfs_guard_lkm.ko"                        # Local target file path for the downloaded kernel module
:"SUSFS"                                                                   #
SUSFS_MODULE_NAME="susfs_guard_lkm"                                        # Kernel module name in lsmod
SUSFS_KSU_SUSFS_BIN="/data/adb/ksu/bin/ksu_susfs"                          # Path to the ksu_susfs binary
:"REBOOT"                                                                  #
REBOOT_FLAG="$MOD_DIR/reboot"                                              # Flag file to indicate that a reboot is required after module update

. "$MODDIR/lib/log.sh"
. "$MODDIR/lib/download.sh"
. "$MODDIR/lib/upstream.sh"
. "$MODDIR/lib/status.sh"

return 0
