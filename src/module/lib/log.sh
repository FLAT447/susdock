#!/system/bin/sh

LOG_LEVEL="${LOG_LEVEL:-INFO}"
LOG_MAX_BYTES="${LOG_MAX_BYTES:-1048576}" # Default to 1MB

LOG_DIR="$DATA_DIR/logs"
LOG_FILE="$LOG_DIR/module.log"

# Level Map
_level_num() {
    case "$1" in
        DEBUG) echo 0 ;;
        INFO) echo 1 ;;
        WARN) echo 2 ;;
        ERROR) echo 3 ;;
        *) echo 1 ;;
    esac
}

# Usage: log <level> <message>
#   level: DEBUG | INFO | WARN | ERROR
log() {
    level="$1"
    shift
    msg="$*"

    # filter
    [ "$(_level_num "$level")" -ge "$(_level_num "$LOG_LEVEL")" ] || return 0

    ts=$(date '+%Y-%m-%d %H:%M:%S' 2> /dev/null || echo "----")
    line="[$ts] [$level] $msg"

    # stderr
    echo "$line" >&2

    # file
    mkdir -p "$LOG_DIR" 2> /dev/null || return 0
    # Slice log files
    if [ -f "$LOG_FILE" ]; then
        size=$(wc -c < "$LOG_FILE" 2> /dev/null || echo 0)
        [ "$size" -gt "$LOG_MAX_BYTES" ] && mv "$LOG_FILE" "$LOG_FILE.1" 2> /dev/null
    fi
    echo "$line" >> "$LOG_FILE" 2> /dev/null

    return 0
}

# Clear the log file
log_clear() { : > "$LOG_FILE" 2> /dev/null; }

# Get the log file path
log_path() { echo "$LOG_FILE"; }
