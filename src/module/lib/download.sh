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
    url="$1"
    dest="$2"

    [ -n "$url" ] || {
        log ERROR "download: missing url"
        return "$DL_ERR_ARG"
    }

    [ -n "$dest" ] || {
        log ERROR "download: missing dest"
        return "$DL_ERR_ARG"
    }

    tool=$(_dl_tool)
    [ -n "$tool" ] || {
        log ERROR "no download tool available"
        return "$DL_ERR_TOOL"
    }

    dest_dir=$(dirname "$dest")
    [ -d "$dest_dir" ] || mkdir -p "$dest_dir" 2> /dev/null || {
        log ERROR "cannot create dir: $dest_dir"
        return "$DL_ERR_MKDIR"
    }

    tmp="$dest.tmp.$$"
    log INFO "download [$tool]: $url -> $dest"

    case "$tool" in
        curl) curl -fsSL --connect-timeout 15 -o "$tmp" "$url" ;;
        wget) wget -q --timeout=15 -O "$tmp" "$url" ;;
        busybox_wget) busybox wget -q -O "$tmp" "$url" ;;
    esac
    rc=$?

    if [ "$rc" -ne 0 ]; then
        rm -f "$tmp"
        log ERROR "download failed: $url"
        return "$DL_ERR_NET"
    fi

    if [ ! -s "$tmp" ]; then
        rm -f "$tmp"
        log ERROR "downloaded file is empty: $url"
        return "$DL_ERR_EMPTY"
    fi

    mv "$tmp" "$dest" || {
        rm -f "$tmp"
        log ERROR "cannot write: $dest"
        return "$DL_ERR_WRITE"
    }

    log INFO "download done: $dest"
    return 0
}
