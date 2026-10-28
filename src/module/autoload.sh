#!/system/bin/sh

# WebUI 的开关会把本脚本复制到 /data/adb/post-fs-data.d/<id>.sh，
# KernelSU 在 post-fs-data 阶段执行它。
# 故意不 source lib/*.sh：启动路径必须独立，辅助脚本出错也不能拖住开机。
# 日志直接追加到模块日志，格式与 lib/log.sh 保持一致。

MODDIR=${0%/*}

# 从 post-fs-data.d 执行时脚本不在模块目录里，按文件名回推模块目录。
if [ ! -d "${MODDIR}/lib" ]; then
    MODDIR="/data/adb/modules/$(basename "$0" .sh)"
fi

DATA_DIR="/data/adb/$(basename "${MODDIR}")"
KO_FILE="${DATA_DIR}/mod/susfs_guard_lkm.ko"
LOG_FILE="${DATA_DIR}/logs/module.log"
MODULE_NAME="susfs_guard_lkm"

log() {
    _ts=$(date '+%Y-%m-%d %H:%M:%S' 2> /dev/null || echo "----")
    _line="[${_ts}] [INFO] $*"

    mkdir -p "${DATA_DIR}/logs" 2> /dev/null
    echo "${_line}" >> "${LOG_FILE}" 2> /dev/null
    echo "${_line}" >&2
}

# 模块被 KernelSU 禁用时不加载。本脚本在 post-fs-data.d/ 里，
# 不受模块启用状态影响，必须自己检查。
[ -f "${MODDIR}/disable" ] && {
    log "susfs: module is disabled, skip loading"
    exit 0
}

# 没下载过驱动时静默跳过：全新安装还没点过更新，属于正常状态。
[ -f "${KO_FILE}" ] || {
    log "susfs: driver not found, skip loading: ${KO_FILE}"
    exit 0
}

# 重复 insmod 会报 File exists，先看一眼是否已加载。
if lsmod 2> /dev/null | grep -q "^${MODULE_NAME} "; then
    log "susfs: already loaded"
    exit 0
fi

# 绝对路径，避免 post-fs-data 阶段工作目录不确定。
if _out=$(insmod "${KO_FILE}" 2>&1); then
    log "susfs: loaded ${KO_FILE}"
    # 新驱动已经在跑，重启标记不再需要。
    rm -f "${DATA_DIR}/mod/reboot" 2> /dev/null
else
    log "susfs: insmod failed: ${_out:-unknown error}"
    exit 1
fi
