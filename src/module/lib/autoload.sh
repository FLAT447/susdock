#!/system/bin/sh

# 开机加载开关。
# 默认：模块目录里的 post-fs-data.sh 由 KernelSU 执行。
# 开启：把 post-fs-data.sh 重命名为 .post-fs-data.sh（不再执行），
#       同时复制到 post-fs-data.d/，让它在 post-fs-data 阶段优先加载。
# 关闭：删除副本，把 .post-fs-data.sh 改回 post-fs-data.sh。

MODULE_ID=$(basename "$MODDIR")
AUTOLOAD_SOURCE="${MODDIR}/post-fs-data.sh"
AUTOLOAD_HIDDEN="${MODDIR}/.post-fs-data.sh"
AUTOLOAD_DIR="/data/adb/post-fs-data.d"
AUTOLOAD_TARGET="${AUTOLOAD_DIR}/${MODULE_ID}.sh"

# Usage: autoload_enabled
# Returns 0 when the priority copy is installed
autoload_enabled() {
    [ -f "$AUTOLOAD_TARGET" ]
}

# Usage: autoload_enable
# Returns 0 on success, 1 on failure
autoload_enable() {
    # 已经在优先模式时，模块里的那份是隐藏文件
    _au_src="$AUTOLOAD_SOURCE"
    [ -f "$_au_src" ] || _au_src="$AUTOLOAD_HIDDEN"
    [ -f "$_au_src" ] || {
        log ERROR "boot script not found: $AUTOLOAD_SOURCE"
        return 1
    }

    mkdir -p "$AUTOLOAD_DIR" 2> /dev/null || {
        log ERROR "cannot create $AUTOLOAD_DIR"
        return 1
    }

    # 先写好优先副本，再隐藏模块自带的那份，避免出现没有加载脚本的窗口
    cp "$_au_src" "$AUTOLOAD_TARGET" 2> /dev/null || {
        log ERROR "cannot write $AUTOLOAD_TARGET"
        return 1
    }

    chmod 755 "$AUTOLOAD_TARGET" 2> /dev/null || {
        log ERROR "cannot chmod $AUTOLOAD_TARGET"
        return 1
    }

    if [ -f "$AUTOLOAD_SOURCE" ]; then
        mv -f "$AUTOLOAD_SOURCE" "$AUTOLOAD_HIDDEN" 2> /dev/null || {
            log ERROR "cannot hide $AUTOLOAD_SOURCE"
            return 1
        }
    fi

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

    if [ -f "$AUTOLOAD_HIDDEN" ]; then
        mv -f "$AUTOLOAD_HIDDEN" "$AUTOLOAD_SOURCE" 2> /dev/null || {
            log ERROR "cannot restore $AUTOLOAD_SOURCE"
            return 1
        }
    fi

    log INFO "autoload disabled"
    return 0
}
