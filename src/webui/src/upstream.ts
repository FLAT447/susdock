/*
 * 更新源设置：存在 localStorage，调用后端时通过环境变量传给 entry.sh。
 * 后端只消费 UPSTREAM_API / UPSTREAM_MIRROR，不写任何配置文件。
 * 内置地址与 src/module/lib/common.sh 保持一致。
 */

export type UpstreamPreset = "custom" | "mirror" | "official";

export interface UpstreamSetting {
    /** Releases API 地址 */
    api: string;
    /** 驱动下载加速前缀，空串表示直连 */
    mirror: string;
    preset: UpstreamPreset;
}

export const OFFICIAL_API = "https://api.github.com/repos/inforcqb/susfs4ksu-lkm/releases/latest";
export const MIRROR_PREFIX = "https://ghfast.top/";

const KEY = "upstream";
const MIN_URL = "https://".length + 1;

function isHttps(value: unknown): value is string {
    return typeof value === "string" && value.length >= MIN_URL && value.startsWith("https://");
}

function presetOf(api: string, mirror: string): UpstreamPreset {
    if (mirror !== "") {
        return "mirror";
    }

    return api === OFFICIAL_API ? "official" : "custom";
}

export function presetSetting(preset: Exclude<UpstreamPreset, "custom">): UpstreamSetting {
    return preset === "mirror"
        ? { api: OFFICIAL_API, mirror: MIRROR_PREFIX, preset: "mirror" }
        : { api: OFFICIAL_API, mirror: "", preset: "official" };
}

export function customSetting(api: string): UpstreamSetting {
    return { api, mirror: "", preset: "custom" };
}

export function loadUpstream(): UpstreamSetting {
    try {
        const raw = localStorage.getItem(KEY);
        if (raw !== null) {
            const parsed = JSON.parse(raw) as { api?: unknown; mirror?: unknown };
            const api = isHttps(parsed.api) ? parsed.api : OFFICIAL_API;
            const mirror = isHttps(parsed.mirror) ? parsed.mirror : "";

            return { api, mirror, preset: presetOf(api, mirror) };
        }
    }
    catch {
        // 隐私模式或数据损坏时当作没设置过
    }

    return presetSetting("official");
}

export function saveUpstream(setting: UpstreamSetting): void {
    try {
        localStorage.setItem(KEY, JSON.stringify(setting));
    }
    catch {
        // 存不了只影响下次打开
    }
}
