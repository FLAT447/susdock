#!/system/bin/sh

# 默认由 KernelSU 执行模块目录里的本脚本。
# WebUI 开启「开机优先加载」后，本脚本会被重命名为 .post-fs-data.sh，
# 并复制到 /data/adb/post-fs-data.d/<id>.sh，由后者优先执行。
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

# 更新程序写入固定的 susfs_guard_lkm.ko；手动放进来的文件可能保留上游
# 资产名（susfs_guard_lkm-android15-6.6.ko），这种情况下取目录里的第一个。
if [ ! -f "${KO_FILE}" ]; then
    for _boot_ko in "${DATA_DIR}/mod/"*.ko; do
        [ -f "${_boot_ko}" ] && {
            KO_FILE="${_boot_ko}"
            break
        }
    done
fi

log() {
    _al_ts=$(date '+%Y-%m-%d %H:%M:%S' 2> /dev/null || echo "----")
    _al_line="[${_al_ts}] [INFO] $*"

    mkdir -p "${DATA_DIR}/logs" 2> /dev/null
    echo "${_al_line}" >> "${LOG_FILE}" 2> /dev/null
    echo "${_al_line}" >&2
}

# 模块被 KernelSU 禁用时不加载。本脚本在 post-fs-data.d/ 里，
# 不受模块启用状态影响，必须自己检查。
[ -f "${MODDIR}/disable" ] && {
    log "susfs: module is disabled, skip loading"
    exit 0
}

# 没下载过驱动时静默跳过：全新安装还没点过更新，属于正常状态。
[ -f "${KO_FILE}" ] || {
    log "susfs: driver not found, skip loading: ${DATA_DIR}/mod"
    exit 0
}

# 重复 insmod 会报 File exists，先看一眼是否已加载。lsmod 可以直接运行。
if lsmod 2> /dev/null | grep -q "^${MODULE_NAME} "; then
    log "susfs: already loaded"
    exit 0
fi

# insmod 必须走 ksud，直接调用系统 insmod 在 KernelSU 环境里会失败。
KSUD_BIN=$(command -v ksud 2> /dev/null)
if [ -z "${KSUD_BIN}" ]; then
    for _boot_ksud in /data/adb/ksud /data/adb/ksu/bin/ksud; do
        [ -x "${_boot_ksud}" ] && {
            KSUD_BIN="${_boot_ksud}"
            break
        }
    done
fi

[ -n "${KSUD_BIN}" ] || {
    log "susfs: ksud not found, cannot load driver"
    exit 1
}

if _al_out=$("${KSUD_BIN}" insmod "${KO_FILE}" 2>&1); then
    log "susfs: loaded ${KO_FILE}"
    # 新驱动已经在跑，重启标记不再需要。
    rm -f "${DATA_DIR}/mod/reboot" 2> /dev/null
else
    log "susfs: ksud insmod failed: ${_al_out:-unknown error}"
    exit 1
fi
