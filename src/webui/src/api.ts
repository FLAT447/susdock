/*
 * 和模块里的 shell 脚本打交道。界面相关的东西一概不放在这里。
 * 接口细节见 docs/backend-api.md。
 */
import { exec, moduleInfo } from "kernelsu";
import { first, parseKV } from "./protocol";
import { loadUpstream } from "./upstream";

const FALLBACK_MODULE_ID = "susdock";
const MODULE_ROOT = "/data/adb/modules";
const MAX_LOG_LINES = 2000;

export type LogLevel = "DEBUG" | "ERROR" | "INFO" | "WARN";

export interface ModuleStatus {
    android: string;
    kernel: string;
    koSize: number;
    loaded: boolean;
    local: string;
    rebootRequired: boolean;
    running: string;
}

export type UpdateCheck =
    | { state: "available"; version: string }
    | { state: "current"; version: string }
    | { state: "error"; message: string };

export interface UpdateResult {
    errno: number;
    log: string;
    ok: boolean;
}

interface ExecOutput {
    errno: number;
    stderr: string;
    stdout: string;
}

// module.prop 的 id 由 package.json 的 name 生成，不要写死路径
function moduleDir(): string {
    try {
        const info = JSON.parse(moduleInfo()) as { id?: unknown };
        if (typeof info.id === "string" && /^[\w.-]+$/.test(info.id)) {
            return `${MODULE_ROOT}/${info.id}`;
        }
    }
    catch {
        // moduleInfo() 在非 KernelSU 环境不可用
    }

    return `${MODULE_ROOT}/${FALLBACK_MODULE_ID}`;
}

// 单引号包裹，内部单引号按 POSIX 规则转义成 '\''
function shellQuote(value: string): string {
    return `'${value.replaceAll("'", String.raw`'\''`)}'`;
}

// 更新源存在 localStorage，这里通过环境变量交给 entry.sh，脚本不写配置文件
function upstreamEnv(): string {
    const { api, mirror } = loadUpstream();
    let env = `UPSTREAM_API=${shellQuote(api)}`;

    if (mirror !== "") {
        env += ` UPSTREAM_MIRROR=${shellQuote(mirror)}`;
    }

    return `${env} `;
}

function run(args: string): Promise<ExecOutput> {
    if (!("ksu" in globalThis)) {
        return Promise.reject(new Error("未在 KernelSU 环境中运行"));
    }

    return exec(`${upstreamEnv()}sh '${moduleDir()}/entry.sh' ${args}`);
}

async function runOk(args: string): Promise<string> {
    const { errno, stderr, stdout } = await run(args);
    if (errno !== 0) {
        throw new Error(cleanError(stderr || stdout) || `命令失败 (errno ${errno})`);
    }

    return stdout;
}

// stderr 里混着普通日志，取最后一条 [ERROR] 作为错误信息
function cleanError(text: string): string {
    const lines = text.split("\n").map(line => line.trim()).filter(line => line !== "");
    let message = "";

    for (const line of lines) {
        if (line.includes("[ERROR]")) {
            message = line.replace(/^.*\[ERROR\]\s*/, "");
        }
    }

    if (message !== "") {
        return message;
    }

    return lines[lines.length - 1] ?? "";
}

function toNumber(value: string): number {
    const parsed = Number.parseInt(value, 10);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : 0;
}

export async function readStatus(): Promise<ModuleStatus> {
    const map = parseKV(await runOk("status quick"));

    return {
        android: first(map, "android_version", "未知"),
        kernel: first(map, "kernel_version", "未知"),
        koSize: toNumber(first(map, "ko_size", "0")),
        loaded: first(map, "loaded") === "true",
        local: first(map, "local_version", "未知"),
        rebootRequired: first(map, "reboot_required") === "true",
        running: first(map, "running_version", "未知"),
    };
}

/*
 * `mod check` 用退出码表达结果：
 *   0 → 有新版本，stdout 是上游 tag
 *   1 → 已是最新（stderr 里没有 [ERROR]）
 *   >1 → 出错
 */
export async function checkUpdate(): Promise<UpdateCheck> {
    const { errno, stderr, stdout } = await run("mod check");

    if (errno === 0) {
        return { state: "available", version: stdout.trim() };
    }

    if (stderr.includes("[ERROR]")) {
        return { state: "error", message: cleanError(stderr) };
    }

    return { state: "current", version: "" };
}

export async function applyUpdate(): Promise<UpdateResult> {
    const { errno, stderr, stdout } = await run("mod update");
    const log = [stderr, stdout]
        .filter(part => part.trim() !== "")
        .join("\n")
        .trim();

    return { errno, log, ok: errno === 0 };
}

/*
 * 开机加载开关的状态就是 post-fs-data.d/ 里有没有本模块的脚本，
 * 所以每次都问后端，不在前端缓存。
 */
export async function readAutoload(): Promise<boolean> {
    const map = parseKV(await runOk("mod autoload"));
    return first(map, "enabled") === "true";
}

export async function setAutoload(enabled: boolean): Promise<boolean> {
    const map = parseKV(await runOk(`mod autoload ${enabled ? "on" : "off"}`));
    return first(map, "enabled") === "true";
}

export function readLog(lines = 300): Promise<string> {
    const count = Math.min(Math.max(Math.trunc(lines), 1), MAX_LOG_LINES);
    return runOk(`log tail ${count}`);
}

export async function clearLog(): Promise<void> {
    await runOk("log clear");
}

function isLogLevel(value: string): value is LogLevel {
    return value === "DEBUG" || value === "INFO" || value === "WARN" || value === "ERROR";
}

export async function readLogLevel(): Promise<LogLevel> {
    const value = (await runOk("log level")).trim().toUpperCase();
    return isLogLevel(value) ? value : "INFO";
}

export async function setLogLevel(level: LogLevel): Promise<LogLevel> {
    const value = (await runOk(`log set-level ${level}`)).trim().toUpperCase();
    return isLogLevel(value) ? value : level;
}

// 模块自身的版本，从管理器拿；拿不到就返回空串
export function moduleVersion(): string {
    try {
        const info = JSON.parse(moduleInfo()) as { version?: unknown };
        return typeof info.version === "string" ? info.version : "";
    }
    catch {
        return "";
    }
}
