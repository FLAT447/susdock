#!/system/bin/sh

# Log error codes
LOG_ERR_ARG=1
LOG_ERR_WRITE=2

# Print the last N log lines. The rotated backup is prepended when it exists so
# a just-rotated log does not look empty.
# Usage: log_tail [lines]
log_tail() {
    _tail_n="${1:-200}"

    case "$_tail_n" in
        '' | *[!0-9]*) _tail_n=200 ;;
    esac
    [ "$_tail_n" -eq 0 ] && _tail_n=200

    _tail_file=$(log_path)
    _tail_bak="${_tail_file}.1"

    if [ -f "$_tail_bak" ]; then
        cat "$_tail_bak" "$_tail_file" 2> /dev/null | tail -n "$_tail_n"
    elif [ -f "$_tail_file" ]; then
        tail -n "$_tail_n" "$_tail_file" 2> /dev/null
    fi

    return 0
}

# Truncate the current log and drop the rotated backup.
# Usage: log_clear_all
log_clear_all() {
    _clear_file=$(log_path)
    log_clear
    rm -f "${_clear_file}.1" 2> /dev/null

    return 0
}

# Print the effective log level.
# Usage: log_level_get
log_level_get() {
    echo "$LOG_LEVEL"
    return 0
}

# Persist a new log level. The level applies to later invocations, because the
# level is read from the config file when a command starts.
# Usage: log_level_set <DEBUG|INFO|WARN|ERROR>
log_level_set() {
    _level_arg=$(printf '%s' "${1:-}" | tr '[:lower:]' '[:upper:]')

    case "$_level_arg" in
        DEBUG | INFO | WARN | ERROR) ;;
        *)
            log ERROR "invalid log level: ${1:-<empty>}"
            return "$LOG_ERR_ARG"
            ;;
    esac

    config_set LOG_LEVEL "$_level_arg" || {
        log ERROR "cannot write config: $CONFIG_FILE"
        return "$LOG_ERR_WRITE"
    }

    LOG_LEVEL="$_level_arg"
    log INFO "log level set to $_level_arg"
    echo "$_level_arg"
    return 0
}

# Dispatch log subcommands
# Usage: log_dispatch <subcommand> [args...]
log_dispatch() {
    _sub="${1:-}"
    [ -n "$_sub" ] && shift
    case "$_sub" in
        tail) log_tail "$@" ;;
        clear) log_clear_all "$@" ;;
        level) log_level_get "$@" ;;
        set-level) log_level_set "$@" ;;
        *) err "unknown log subcommand: ${_sub:-<empty>}" ;;
    esac
}
