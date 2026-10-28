import { execSync } from "node:child_process";
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";

import { exit } from "node:process";
import packageJson from "../package.json" with { type: "json" };
import { log, Types } from "./log.ts";
import { parseVersion } from "./version.ts";

/**
 * "entries" is the list of files and directories to copy from the module directory to the dist directory.
 */

const entries = [
    "autoload.sh",
    "entries",
    "entry.sh",
    "lib",
    "uninstall.sh",
];

const rootPath = join(import.meta.dirname, "..");
const modulePath = join(rootPath, "src/module");
const webuiDistPath = join(rootPath, "src/webui/dist");
const distPath = join(rootPath, "dist");
// 模块文件先落到 dist/source，再由它压成 dist/<name>-<tag>.zip
const sourcePath = join(distPath, "source");

function buildModuleProps() {
    return {
        id: packageJson.name,
        name: packageJson.kernelsu.name,
        version: packageJson.version,
        versionCode: parseVersion(packageJson.version).versionCode,
        author:
      typeof packageJson.author === "string"
          ? packageJson.author
          : packageJson.author?.name ?? "",
        updateJson: packageJson.kernelsu.updateJson,
        description: packageJson.description,
    } as const;
}

type ModuleProps = ReturnType<typeof buildModuleProps>;

function renderModuleProp(moduleProps: ModuleProps): string {
    log("Generating module.prop...", Types.detail);
    const content = readFileSync(join(modulePath, "module.prop"), "utf-8");

    return content.replaceAll(/\{(\w+)\}/g, (match, key) => {
        if (key in moduleProps)
            return String(moduleProps[key as keyof ModuleProps]);
        return match;
    });
}

function main(): void {
    log("Module build starts.");

    const moduleProps = buildModuleProps();

    rmSync(distPath, { recursive: true, force: true });
    mkdirSync(sourcePath, { recursive: true });
    writeFileSync(join(sourcePath, "module.prop"), renderModuleProp(moduleProps));

    for (const entry of entries) {
        log(`Copying entry(${entry})...`, Types.detail);
        const path = join(modulePath, entry);
        if (!existsSync(path))
            throw new Error(`"${entry}" does not exist at "${path}"!`);
        cpSync(path, join(sourcePath, entry), { recursive: true });
    }

    log("Module build completed successfully.", Types.success);

    log("WebUI build starts.");
    try {
        execSync("pnpm run webui:build", { stdio: "inherit", cwd: rootPath });
    }
    catch (err) {
        const detail = err instanceof Error ? err.message : String(err);
        throw new Error(`WebUI build failed: ${detail}`);
    }

    if (!existsSync(webuiDistPath))
        throw new Error(`WebUI dist not found at "${webuiDistPath}"`);

    // KernelSU only serves the WebUI from a `webroot` directory.
    cpSync(webuiDistPath, join(sourcePath, "webroot"), { recursive: true });
    log("WebUI build completed successfully.", Types.success);
}

try {
    main();
}
catch (err) {
    log(err instanceof Error ? err.message : String(err), Types.error);
    exit(1);
}
