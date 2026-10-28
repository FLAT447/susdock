#!/system/bin/sh

# KernelSU 卸载模块时执行。
# 清掉植入 post-fs-data.d/ 的加载脚本，否则卸载后每次开机仍会尝试加载
# 已被删除的 .ko。

MODDIR=${0%/*}
MODULE_ID=$(basename "$MODDIR")

rm -f "/data/adb/post-fs-data.d/${MODULE_ID}.sh" 2> /dev/null

exit 0
