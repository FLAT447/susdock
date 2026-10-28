#!/system/bin/sh

# Download error codes
DL_ERR_ARG=1
DL_ERR_TOOL=2
DL_ERR_MKDIR=3
DL_ERR_NET=4
DL_ERR_EMPTY=5
DL_ERR_WRITE=6

_dl_tool() {
    command -v curl > /dev/null 2>&1 && {
        echo curl
        return
    }
    command -v wget > /dev/null 2>&1 && {
        echo wget
        return
    }
    command -v busybox > /dev/null 2>&1 && busybox wget --help > /dev/null 2>&1 && {
        echo busybox_wget
        return
    }
    echo ""
}

# Usage: download <url> <dest>
#   url: The URL to download from
#   dest: The destination file path to save the downloaded content
# Returns 0 on success, non-zero on failure.
download() {
    _url="$1"
    _dest="$2"

    [ -n "$_url" ] || {
        log ERROR "download: missing url"
        return "$DL_ERR_ARG"
    }

    [ -n "$_dest" ] || {
        log ERROR "download: missing dest"
        return "$DL_ERR_ARG"
    }

    _tool=$(_dl_tool)
    [ -n "$_tool" ] || {
        log ERROR "no download tool available"
        return "$DL_ERR_TOOL"
    }

    _dest_dir=$(dirname "$_dest")
    [ -d "$_dest_dir" ] || mkdir -p "$_dest_dir" 2> /dev/null || {
        log ERROR "cannot create dir: $_dest_dir"
        return "$DL_ERR_MKDIR"
    }

    _tmp="$_dest.tmp.$$"
    log INFO "download [$_tool]: $_url -> $_dest"

    case "$_tool" in
        curl) curl -fsSL --connect-timeout 15 -o "$_tmp" "$_url" ;;
        wget) wget -q --timeout=15 -O "$_tmp" "$_url" ;;
        busybox_wget) busybox wget -q -O "$_tmp" "$_url" ;;
    esac
    _rc=$?

    if [ "$_rc" -ne 0 ]; then
        rm -f "$_tmp"
        log ERROR "download failed: $_url"
        return "$DL_ERR_NET"
    fi

    if [ ! -s "$_tmp" ]; then
        rm -f "$_tmp"
        log ERROR "downloaded file is empty: $_url"
        return "$DL_ERR_EMPTY"
    fi

    mv "$_tmp" "$_dest" || {
        rm -f "$_tmp"
        log ERROR "cannot write: $_dest"
        return "$DL_ERR_WRITE"
    }

    log INFO "download done: $_dest"
    return 0
}
