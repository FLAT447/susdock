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
    _dl_url="$1"
    _dl_dest="$2"

    [ -n "$_dl_url" ] || {
        log ERROR "download: missing url"
        return "$DL_ERR_ARG"
    }

    [ -n "$_dl_dest" ] || {
        log ERROR "download: missing dest"
        return "$DL_ERR_ARG"
    }

    _dl_tool=$(_dl_tool)
    [ -n "$_dl_tool" ] || {
        log ERROR "no download tool available"
        return "$DL_ERR_TOOL"
    }

    _dl_dir=$(dirname "$_dl_dest")
    [ -d "$_dl_dir" ] || mkdir -p "$_dl_dir" 2> /dev/null || {
        log ERROR "cannot create dir: $_dl_dir"
        return "$DL_ERR_MKDIR"
    }

    _dl_tmp="$_dl_dest.tmp.$$"
    log INFO "download [$_dl_tool]: $_dl_url -> $_dl_dest"

    case "$_dl_tool" in
        curl) curl -fsSL --connect-timeout 15 -o "$_dl_tmp" "$_dl_url" ;;
        wget) wget -q --timeout=15 -O "$_dl_tmp" "$_dl_url" ;;
        busybox_wget) busybox wget -q -O "$_dl_tmp" "$_dl_url" ;;
    esac
    _dl_rc=$?

    if [ "$_dl_rc" -ne 0 ]; then
        rm -f "$_dl_tmp"
        log ERROR "download failed: $_dl_url"
        return "$DL_ERR_NET"
    fi

    if [ ! -s "$_dl_tmp" ]; then
        rm -f "$_dl_tmp"
        log ERROR "downloaded file is empty: $_dl_url"
        return "$DL_ERR_EMPTY"
    fi

    mv "$_dl_tmp" "$_dl_dest" || {
        rm -f "$_dl_tmp"
        log ERROR "cannot write: $_dl_dest"
        return "$DL_ERR_WRITE"
    }

    log INFO "download done: $_dl_dest"
    return 0
}
