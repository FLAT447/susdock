import { execFileSync } from "node:child_process";
import { existsSync, readdirSync, rmSync, statSync } from "node:fs";
import { join } from "node:path";

import { exit } from "node:process";
import packageJson from "../package.json" with { type: "json" };
import { log, Types } from "./log.ts";
import { parseVersion } from "./version.ts";

/**
 * 把 dist/source 压成 KernelSU 可刷入的 zip，产物落在 dist/ 下。
 * 压缩包根目录必须是 module.prop，所以以 source 作为工作目录打包。
 */

const rootPath = join(import.meta.dirname, "..");
const distPath = join(rootPath, "dist");
const sourcePath = join(distPath, "source");

function fatal(message: string): never {
    log(message, Types.error);
    exit(1);
}

function main(): void {
    if (!existsSync(sourcePath))
        fatal(`"${sourcePath}" 不存在，请先运行 pnpm build`);
    if (!statSync(sourcePath).isDirectory())
        fatal(`"${sourcePath}" 不是目录`);

    const { versionCode } = parseVersion(packageJson.version);
    const tag = `v${packageJson.version}-${versionCode}`;
    const zipName = `${packageJson.name}-${tag}.zip`;
    const zipPath = join(distPath, zipName);

    // 重复打包时先删旧包，否则 zip 会把新条目追加进已有归档
    rmSync(zipPath, { force: true });

    const targets = readdirSync(sourcePath).filter(name => !name.startsWith("."));
    if (targets.length === 0)
        fatal(`"${sourcePath}" 是空的，没有可打包的内容`);

    log(`Packing ${zipName}...`, Types.detail);

    try {
        execFileSync("zip", ["-r", "-X", "-9", zipPath, ...targets], {
            cwd: sourcePath,
            stdio: "inherit",
        });
    }
    catch (err) {
        const detail = err instanceof Error ? err.message : String(err);
        throw new Error(`打包失败：${detail}`);
    }

    if (!existsSync(zipPath))
        throw new Error(`打包后找不到 "${zipPath}"`);

    const sizeKiB = (statSync(zipPath).size / 1024).toFixed(1);
    log(`Packed ${zipName} (${sizeKiB} KiB).`, Types.success);
}

try {
    main();
}
catch (err) {
    log(err instanceof Error ? err.message : String(err), Types.error);
    exit(1);
}
