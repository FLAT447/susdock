import type { ModuleStatus } from "../api";
import type { SdBadge } from "./sd-badge";
import type { SdRow } from "./sd-row";
import { requireElement } from "./dom";
import "./sd-badge";
import "./sd-row";

const FIELDS = ["android", "kernel", "running", "local", "koSize"] as const;

function formatSize(bytes: number): string {
    if (!Number.isFinite(bytes) || bytes <= 0) {
        return "-";
    }

    const units = ["B", "KB", "MB", "GB"];
    let value = bytes;
    let unit = 0;

    while (value >= 1024 && unit < units.length - 1) {
        value /= 1024;
        unit++;
    }

    return `${unit === 0 ? value : value.toFixed(1)} ${units[unit]}`;
}

/*
 * 状态卡：只负责显示，数据由 sd-app 拉取后写入。
 * DOM 全部来自 index.html。
 */
export class SdStatusCard extends HTMLElement {
    setStatus(status: ModuleStatus): void {
        const badge = requireElement<SdBadge>(this, "#state-badge");
        badge.textContent = status.loaded ? "● 已加载" : "● 未加载";
        badge.tone = status.loaded ? "ok" : "fail";

        requireElement(this, "#reboot-badge").hidden = !status.rebootRequired;

        this.setField("android", status.android);
        this.setField("kernel", status.kernel);
        this.setField("running", status.running);
        this.setField("local", status.local);
        this.setField("koSize", formatSize(status.koSize));
    }

    setError(message: string): void {
        const badge = requireElement<SdBadge>(this, "#state-badge");
        badge.textContent = "读取失败";
        badge.tone = "fail";
        badge.title = message;

        requireElement(this, "#reboot-badge").hidden = true;

        for (const field of FIELDS) {
            this.setField(field, "-");
        }
    }

    private setField(field: string, value: string): void {
        requireElement<SdRow>(this, `sd-row[data-field="${field}"]`).value = value;
    }
}

if (!customElements.get("sd-status-card")) {
    customElements.define("sd-status-card", SdStatusCard);
}
