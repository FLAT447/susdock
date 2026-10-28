# SusDock 模块接口文档

写给 WebUI 前端。后端代码在 `src/module/`，这里记录的是脚本当前的输出和行为。

## 1. 运行环境

KernelSU 用 WebView 打开模块 `webroot/` 下的页面。前端通过 `kernelsu` 包的 `exec()` 调脚本：

```ts
import { exec, moduleInfo } from "kernelsu";

const { id } = JSON.parse(moduleInfo()) as { id: string };
const result = await exec(`sh '/data/adb/modules/${id}/entry.sh' status quick`);

if (result.errno !== 0) {
    throw new Error(result.stderr);
}
// 成功时 result.stdout 是 key=value 行，result.stderr 是运行日志
```

模块目录按 `module.prop` 的 `id` 定位：

```
/data/adb/modules/<id>
```

`id` 由 `package.json` 的 `name` 生成，当前是 `susdock`。前端用 `moduleInfo()` 返回的 `id` 拼路径，不要写死。

## 2. 调用约定

入口只有一个：

```sh
sh <moddir>/entry.sh <command> [subcommand] [args...]
```

### 2.1 stdout / stderr

| 流     | 内容                                                       |
| ------ | ---------------------------------------------------------- |
| stdout | 只放机器可读的结果：`key=value` 行、单个值，或原始日志文本 |
| stderr | 运行日志，格式 `[YYYY-MM-DD HH:MM:SS] [LEVEL] message`     |

`key=value` 行只用小写 key，匹配 `^[a-z_][a-z0-9_]*=.*$`。同一个 key 可能出现多次（多行内容），取第一次的值即可。

### 2.2 退出码

| 退出码 | 含义                   |
| ------ | ---------------------- |
| `0`    | 成功 / 布尔命令为真    |
| `1`    | 通用失败；布尔命令为假 |
| `>1`   | 具体错误码，见第 6 节  |

`err()` 会往 stderr 写 `[ERROR] <message>`，然后 `exit 1`。所以退出码为 1 时要再看一眼 stderr：有 `[ERROR]` 是执行失败，没有就是正常的否定结果。

### 2.3 前置检查

每次调用都会先过这几关：

| 条件                               | stderr                                 | 退出码 |
| ---------------------------------- | -------------------------------------- | ------ |
| `MODDIR` 未设置                    | `[ERROR] MODDIR not set`               | 1      |
| 模块被禁用（存在 `disable` 文件）  | `[ERROR] module is disabled`           | 1      |
| 模块标记卸载（存在 `remove` 文件） | `[ERROR] module is marked for removal` | 1      |
| 命令未知                           | `[ERROR] invalid command: <cmd>`       | 1      |

## 3. 路径

| 变量                    | 路径                                    | 说明                             |
| ----------------------- | --------------------------------------- | -------------------------------- |
| `DATA_DIR`              | `/data/adb/<id>`                        | 模块数据目录                     |
| `MOD_DIR`               | `/data/adb/<id>/mod`                    | 驱动与版本文件                   |
| `CONFIG_FILE`           | `/data/adb/<id>/config`                 | 持久化设置，当前只认 `LOG_LEVEL` |
| `LOG_FILE`              | `/data/adb/<id>/logs/module.log`        | 当前日志                         |
| 轮转日志                | `/data/adb/<id>/logs/module.log.1`      | 超过 1 MiB 时轮转                |
| `UPSTREAM_VERSION_FILE` | `/data/adb/<id>/mod/version`            | 已安装的上游版本（即 tag）       |
| `UPSTREAM_LOCAL_TARGET` | `/data/adb/<id>/mod/susfs_guard_lkm.ko` | 已下载的驱动                     |
| `REBOOT_FLAG`           | `/data/adb/<id>/mod/reboot`             | 存在表示需要重启                 |

## 4. 命令一览

| 命令                     | 作用                  | 网络   |
| ------------------------ | --------------------- | ------ |
| `status installed`       | 驱动是否已加载        | 否     |
| `status susfs_version`   | 运行中的 SuSFS 版本   | 否     |
| `status reboot_required` | 是否需要重启          | 否     |
| `status quick`           | 本机状态汇总          | 否     |
| `mod release`            | 下载上游 release JSON | **是** |
| `mod update`             | 按给定 URL 安装更新   | **是** |
| `mod version`            | 本地已安装版本        | 否     |
| `mod clear-reboot`       | 清除重启标记          | 否     |
| `mod upstream`           | 读取本次生效的更新源  | 否     |
| `mod autoload`           | 读取开机加载开关状态  | 否     |
| `mod autoload on\|off`   | 开启 / 关闭开机加载   | 否     |
| `log tail [lines]`       | 读取日志尾部          | 否     |
| `log clear`              | 清空日志              | 否     |
| `log level`              | 读取日志等级          | 否     |
| `log set-level <LEVEL>`  | 设置日志等级          | 否     |

## 5. 命令详情

### 5.1 `status installed`

```
stdout: true | false
exit:   0 已加载 / 1 未加载或无法检测
```

`lsmod` 不可用时返回 `false`，退出码 1，stderr 里是 `[ERROR] lsmod not available`。

### 5.2 `status susfs_version`

```
stdout: 1.5.2        # 已去掉前缀 v
exit:   0
```

错误码：`1` 找不到 `ksu_susfs`，`2` 取不到版本。

### 5.3 `status reboot_required`

```
stdout: true | false
exit:   0 需要重启 / 1 不需要
```

### 5.4 `status quick`

不联网，适合每次界面刷新调用。

```
android_version=14
kernel_version=6.1
gki_branch=14
loaded=true
reboot_required=false
running_version=1.5.2
local_version=v1.5.2
ko_size=482304
```

| key               | 类型           | 说明                                           |
| ----------------- | -------------- | ---------------------------------------------- |
| `android_version` | string         | `ro.build.version.release`，取不到为 `unknown` |
| `kernel_version`  | string         | 内核主次版本，如 `6.1`                         |
| `gki_branch`      | string         | `uname -r` 里的 `-androidNN-`，取不到为空串    |
| `loaded`          | `true`/`false` | `lsmod` 中是否存在 `susfs_guard_lkm`           |
| `reboot_required` | `true`/`false` | 重启标记文件是否存在                           |
| `running_version` | string         | `ksu_susfs show version`，去 `v` 前缀          |
| `local_version`   | string         | 已安装的上游 tag，取不到为 `unknown`           |
| `ko_size`         | integer        | 本地 `.ko` 字节数，不存在为 `0`                |

`local_version` 来自上游 `tag_name`，可能带 `v` 前缀；`running_version` 已经去掉前缀。前端比较两者前先统一去掉 `v`。

`gki_branch` 用来选上游资产：优先用它，取不到时退回 `android_version` 的主号。

退出码恒为 `0`，单项失败会降级成 `unknown`。

### 5.5 `mod release`

下载上游 release JSON 并原样输出到 stdout。**脚本不解析 JSON**，解析由 WebUI 用 `JSON.parse` 完成。

```
stdout: {"tag_name":"v2.3.0-r18.5","assets":[...]}
exit:   0 成功 / 6 拉取失败
```

下载失败时 stderr 有 `[ERROR] failed to fetch release info`。临时文件写在 `/data/adb/<id>/release.<pid>.json`，输出后删除。

### 5.6 `mod update <version> <url> <sha256>`

按调用方给出的资产安装：下载 `.ko`，校验 sha256，写版本文件，创建重启标记。URL 必须是 `https://` 开头，sha256 为 64 位十六进制。

```
sh entry.sh mod update v2.3.0-r18.5 \
    https://github.com/.../susfs_guard_lkm-android15-6.6.ko \
    7c2a274798fc6afd32e74d20321065612d8d656185fa91764dadcdd29f25f372
stdout: (空)
stderr: [..] [INFO] download [...]: https://... -> /data/adb/<id>/mod/susfs_guard_lkm.ko
        [..] [INFO] update installed: v2.3.0-r18.5 (reboot to take effect)
exit:   0
```

| 退出码 | 含义                          |
| ------ | ----------------------------- |
| `0`    | 安装成功，**重启后生效**      |
| `1`    | 参数缺失，或 URL 不是 https   |
| `2`    | 下载失败                      |
| `3`    | sha256 格式错误，或校验不匹配 |
| `4`    | 写入失败（目录、权限、磁盘）  |

失败时 stderr 最后一行通常以 `[ERROR]` 开头，可以直接展示。

### 5.7 `mod version`

```
stdout: v1.5.2
exit:   0
```

本地版本文件缺失时退出码为 `3`。

### 5.8 `mod clear-reboot`

```
exit: 0 成功 / 1 删除失败
```

### 5.9 `log tail [lines]`

读取日志尾部，输出纯文本，不是 `key=value`。

```
sh entry.sh log tail 200
```

| 参数    | 默认  | 说明                                |
| ------- | ----- | ----------------------------------- |
| `lines` | `200` | 返回行数；非数字或 `0` 时回退为 200 |

- 存在轮转文件 `module.log.1` 时，会先拼上它的内容再截取，避免刚轮转完看起来是空日志。
- 日志文件不存在时输出为空，退出码仍是 `0`。
- 输出固定按时间正序。WebUI 的倒序显示是前端自己翻的，脚本不提供排序参数。

```
[2026-10-27 12:00:00] [INFO] download [curl]: https://... -> /data/adb/...
[2026-10-27 12:00:03] [INFO] download done: /data/adb/...
```

### 5.10 `log clear`

清空 `module.log` 并删掉 `module.log.1`。退出码恒为 `0`。

### 5.11 `log level`

```
stdout: INFO
exit:   0
```

取值：`DEBUG` | `INFO` | `WARN` | `ERROR`。

### 5.12 `log set-level <LEVEL>`

大小写不敏感，写入 `/data/adb/<id>/config`：

```
sh entry.sh log set-level debug
stdout: DEBUG
exit:   0
```

| 退出码 | 含义                          |
| ------ | ----------------------------- |
| `0`    | 成功，stdout 为规范化后的等级 |
| `1`    | 参数不是合法等级              |
| `2`    | 写配置文件失败                |

新等级在下一条命令执行时生效，当前进程不受影响。环境变量 `LOG_LEVEL` 的优先级高于配置文件。

### 5.13 `mod upstream`

读取本次调用实际生效的更新源。配置由 WebUI 存在 `localStorage`，调脚本时通过环境变量传进来，脚本本身不读写上游配置。

```
upstream=https://api.github.com/repos/inforcqb/susfs4ksu-lkm/releases/latest
mirror=
official=https://api.github.com/repos/inforcqb/susfs4ksu-lkm/releases/latest
```

| key        | 说明                           |
| ---------- | ------------------------------ |
| `upstream` | 本次生效的 Releases API 地址   |
| `mirror`   | 驱动下载加速前缀，空串表示直连 |
| `official` | 官方地址（默认值）             |

### 5.14 `mod autoload`

控制开机时是否自动加载已安装的驱动。开关状态就是
`/data/adb/post-fs-data.d/<id>.sh` 是否存在，不写配置文件。

```
sh entry.sh mod autoload        # 读取状态
stdout: enabled=true | enabled=false

sh entry.sh mod autoload on     # 复制脚本，chmod 755
sh entry.sh mod autoload off    # 删除脚本
stdout: enabled=true | enabled=false
```

| 退出码 | 含义                   |
| ------ | ---------------------- |
| `0`    | 成功                   |
| `1`    | 参数不是 `on` / `off`  |
| `4`    | 复制、chmod 或删除失败 |

卸载模块时 `uninstall.sh` 会删掉这个脚本，避免残留。

### 5.15 上游相关环境变量

| 变量              | 说明                                                                               |
| ----------------- | ---------------------------------------------------------------------------------- |
| `UPSTREAM_API`    | Releases API 地址；不是 `https://` 开头时回退为官方地址                            |
| `UPSTREAM_MIRROR` | 驱动下载前缀（如 `https://ghfast.top/`），只作用于 `.ko` 的 `browser_download_url` |

ghfast.top 只代理文件，不代理 `api.github.com`。所以「国内加速」加速的只是驱动下载，版本信息仍从官方 API 取。

调用示例：

```sh
UPSTREAM_API='https://api.github.com/repos/inforcqb/susfs4ksu-lkm/releases/latest' \
UPSTREAM_MIRROR='https://ghfast.top/' \
sh entry.sh mod check
```

### 5.16 日志等级过滤

`log <level> <message>` 只输出大于等于当前等级的日志：

| 等级    | 数值 |
| ------- | ---- |
| `DEBUG` | 0    |
| `INFO`  | 1    |
| `WARN`  | 2    |
| `ERROR` | 3    |

## 6. 错误码汇总

### download.sh

| 码  | 含义               |
| --- | ------------------ |
| 1   | 缺少参数           |
| 2   | 没有可用的下载工具 |
| 3   | 无法创建目录       |
| 4   | 网络请求失败       |
| 5   | 下载内容为空       |
| 6   | 写入失败           |

### upstream.sh

| 码  | 含义         |
| --- | ------------ |
| 3   | 本地文件缺失 |
| 6   | 拉取上游失败 |

### entries/mod.sh

| 码  | 含义                  |
| --- | --------------------- |
| 1   | 参数缺失或 URL 非法   |
| 2   | 下载失败              |
| 3   | sha256 非法或校验失败 |
| 4   | 写入失败              |

### entries/status.sh

| 码  | 含义           |
| --- | -------------- |
| 1   | 依赖工具不可用 |
| 2   | 取版本失败     |

### entries/log.sh

| 码  | 含义     |
| --- | -------- |
| 1   | 参数错误 |
| 2   | 写入失败 |

## 7. 对接注意

1. 状态卡用 `status quick`，不联网，适合每次刷新。
2. 更新检测走 `mod release` + 前端 `JSON.parse`：用 `tag_name` 对比 `local_version`，用 `gki_branch` / `kernel_version` 匹配资产名 `susfs_guard_lkm-android<branch>-<kernel>.ko`。
3. `mod update` 需要显式传版本、URL、sha256；返回 0 只代表文件装好了，要把「重启后生效」说清楚，再刷新状态卡读 `reboot_required`。
4. 日志面板用 `log tail`，纯文本渲染，清空后立刻重新拉。
5. 改完日志等级要提示「下次执行生效」，当前日志不会马上变。
6. `exec()` 可能因为 SELinux、权限或模块被禁用直接失败，`errno !== 0` 必须处理。
