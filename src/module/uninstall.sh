#!/system/bin/sh

# KernelSU 卸载模块时执行。
# 清掉植入 post-fs-data.d/ 的加载脚本，否则卸载后每次开机仍会尝试加载
# 已被删除的 .ko。

MODDIR=${0%/*}
MODULE_ID=$(basename "$MODDIR")
DATA_DIR="/data/adb/${MODULE_ID}"

# 开机脚本
rm -f "/data/adb/post-fs-data.d/${MODULE_ID}.sh" 2> /dev/null

# 驱动文件；日志和配置属于用户数据，保留
rm -f "${DATA_DIR}/mod/"*.ko 2> /dev/null

exit 0
