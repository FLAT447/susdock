#!/system/bin/sh

# 开机加载开关：把模块里的 autoload.sh 复制到 post-fs-data.d/。
# 开关状态就是目标文件是否存在，不额外写配置。

MODULE_ID=$(basename "$MODDIR")
AUTOLOAD_SOURCE="${MODDIR}/autoload.sh"
AUTOLOAD_DIR="/data/adb/post-fs-data.d"
AUTOLOAD_TARGET="${AUTOLOAD_DIR}/${MODULE_ID}.sh"

# Usage: autoload_enabled
# Returns 0 when the boot script is installed
autoload_enabled() {
    [ -f "$AUTOLOAD_TARGET" ]
}

# Usage: autoload_enable
# Returns 0 on success, 1 on failure
autoload_enable() {
    [ -f "$AUTOLOAD_SOURCE" ] || {
        log ERROR "autoload template not found: $AUTOLOAD_SOURCE"
        return 1
    }

    mkdir -p "$AUTOLOAD_DIR" 2> /dev/null || {
        log ERROR "cannot create $AUTOLOAD_DIR"
        return 1
    }

    cp "$AUTOLOAD_SOURCE" "$AUTOLOAD_TARGET" 2> /dev/null || {
        log ERROR "cannot write $AUTOLOAD_TARGET"
        return 1
    }

    chmod 755 "$AUTOLOAD_TARGET" 2> /dev/null || {
        log ERROR "cannot chmod $AUTOLOAD_TARGET"
        return 1
    }

    log INFO "autoload enabled: $AUTOLOAD_TARGET"
    return 0
}

# Usage: autoload_disable
# Returns 0 on success, 1 on failure
autoload_disable() {
    rm -f "$AUTOLOAD_TARGET" 2> /dev/null || {
        log ERROR "cannot remove $AUTOLOAD_TARGET"
        return 1
    }

    log INFO "autoload disabled"
    return 0
}
