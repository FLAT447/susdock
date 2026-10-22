#!/system/bin/sh

MODDIR=${0%/*}

# Unified user-facing error: prints [ERROR] and exits
# Usage: err <message>
err() {
    echo "[ERROR] $*" >&2
    exit 1
}

# Module directory guard
[[ -n "${MODDIR:-}" ]] || err "MODDIR not set"

[[ -e "${MODDIR}/disable" ]] && err "module is disabled"
[[ -e "${MODDIR}/remove" ]] && err "module is marked for removal"

# Load common (loads all libs)
. "${MODDIR}/lib/common.sh" || err "failed to load common.sh"

# Parse command
CMD="${1:-}"
[[ -n "${CMD}" ]] && shift

# Top-level dispatch: each entry provides <cmd>_dispatch
case "$CMD" in
    mod | status)
        # CMD is restricted to the patterns above, so the path is safe to build dynamically.
        # shellcheck disable=SC1090
        . "${MODDIR}/entries/${CMD}.sh" || err "failed to load entries/${CMD}.sh"
        "${CMD}_dispatch" "$@"
        exit $?
        ;;
    *)
        err "invalid command: ${CMD:-<empty>}"
        ;;
esac
