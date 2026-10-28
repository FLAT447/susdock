#!/system/bin/sh

# KernelSU 在安装 / 升级模块后执行本脚本。
# 开机加载开关开启时（post-fs-data.d 里已有副本）：
#   1. 隐藏模块自带的 post-fs-data.sh，避免和优先副本重复执行
#   2. 用新脚本覆盖优先副本，否则升级后仍会跑上一版

MODPATH=${MODPATH:-${0%/*}}

MODULE_ID=$(sed -n 's/^id=//p' "${MODPATH}/module.prop" 2> /dev/null | head -n 1)
[ -n "$MODULE_ID" ] || exit 0

TARGET="/data/adb/post-fs-data.d/${MODULE_ID}.sh"
[ -f "$TARGET" ] || exit 0

SOURCE="${MODPATH}/post-fs-data.sh"
HIDDEN="${MODPATH}/.post-fs-data.sh"

if [ -f "$SOURCE" ]; then
    mv -f "$SOURCE" "$HIDDEN" 2> /dev/null
fi

[ -f "$HIDDEN" ] || exit 0

if cp "$HIDDEN" "$TARGET" 2> /dev/null; then
    chmod 755 "$TARGET" 2> /dev/null
    echo "SusDock: refreshed ${TARGET}"
else
    echo "SusDock: failed to refresh ${TARGET}"
fi

exit 0
