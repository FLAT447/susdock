#!/system/bin/sh

# KernelSU 在安装 / 升级模块后执行本脚本。
# 开机加载开关开启时（post-fs-data.d 里已有副本），用新模板覆盖旧副本；
# 否则升级后 post-fs-data.d 里仍会跑上一版脚本。

MODPATH=${MODPATH:-${0%/*}}

MODULE_ID=$(sed -n 's/^id=//p' "${MODPATH}/module.prop" 2> /dev/null | head -n 1)
[ -n "$MODULE_ID" ] || exit 0

TARGET="/data/adb/post-fs-data.d/${MODULE_ID}.sh"
[ -f "$TARGET" ] || exit 0

SOURCE="${MODPATH}/autoload.sh"
[ -f "$SOURCE" ] || exit 0

if cp "$SOURCE" "$TARGET" 2> /dev/null; then
    chmod 755 "$TARGET" 2> /dev/null
    echo "SusDock: refreshed ${TARGET}"
else
    echo "SusDock: failed to refresh ${TARGET}"
fi

exit 0
