# SusDock

SuSFS 的 LKM 管理器，跑在 KernelSU 上。不在本地编内核模块，按设备指纹去上游取预编译好的 `.ko`。

## 功能

- 查 [inforcqb/susfs4ksu-lkm](https://github.com/inforcqb/susfs4ksu-lkm) 的最新发布
- 按 `<Android 版本>-<内核版本>` 选对应的 `.ko`，sha256 对得上才写进 `/data/adb/susdock/mod/`
- 装完留下重启标记，重启后生效
- WebUI 里可开关「开机自动加载」：开启后把加载脚本写入 `/data/adb/post-fs-data.d/`，卸载模块时自动清理
- 自带 WebUI：看状态、查更新、翻日志（可倒序）、清日志、调等级、换更新源

## 要求

- KernelSU，arm64，GKI 内核
- Android 12 及以上
- 查更新和下载驱动要联网；只看状态不用

## 命令

入口是 `entry.sh`，所有子命令从这里分发：

```sh
MODDIR=/data/adb/modules/susdock

sh "$MODDIR/entry.sh" status quick        # 本机状态（不联网）
sh "$MODDIR/entry.sh" mod release         # 输出上游 release JSON（联网）
sh "$MODDIR/entry.sh" mod update v2.3.0-r18.5 <url> <sha256>  # 下载并安装
sh "$MODDIR/entry.sh" mod autoload on     # 开机自动加载（off 关闭）
sh "$MODDIR/entry.sh" log tail 200        # 日志尾部
sh "$MODDIR/entry.sh" log set-level DEBUG # 改日志等级
```

`mod release` 只负责下载，JSON 由 WebUI 用 `JSON.parse` 解析；`mod update` 需要显式传版本、URL 和 sha256。

参数、输出格式和退出码见 [docs/backend-api.md](docs/backend-api.md)。

## 更新源

默认走 GitHub API 取 releases。「检测更新」卡片右上角的齿轮可以换：

| 选项     | 实际行为                                                        |
| -------- | --------------------------------------------------------------- |
| 官方     | 版本信息和驱动都直连 GitHub                                     |
| 国内加速 | 版本信息仍走 GitHub API，`.ko` 下载套一层 `https://ghfast.top/` |
| 自定义   | 自己填 Releases API 地址                                        |

ghfast.top 只代理文件下载，不接 `api.github.com`（实测返回 403），所以加速只作用在 `.ko` 上。

设置存在浏览器 localStorage，不写进模块配置文件。脚本侧对应 `UPSTREAM_API` 和 `UPSTREAM_MIRROR` 两个环境变量。

## 开发

```sh
pnpm install
pnpm dev          # WebUI 开发服务器
pnpm build        # 构建模块，产物在 dist/source/
pnpm run pack     # 把 dist/source/ 压成 dist/<id>-v<version>-<versionCode>.zip
pnpm test         # 模块脚本回归测试（临时目录 + 假 lsmod/insmod）
pnpm lint         # ESLint + shfmt + shellcheck
```

`dist/source/webroot/` 是 KernelSU 读取的 WebUI 目录，`dist/source/module.prop` 由构建脚本生成。

`build` 和 `pack` 分开是有意的：`build` 只产出目录树，`pack` 只负责打归档，所以本地改完可以直接重打包，不必重跑 WebUI 构建。归档根目录就是 `dist/source/` 的内容，可以直接刷入。Release 工作流两步都会跑。

提交前会自动跑一遍 ESLint（`.githooks/pre-commit`），`pnpm install` 时通过 `core.hooksPath` 挂上。

## 许可

GPL-2.0，见 [LICENSE](LICENSE)。
