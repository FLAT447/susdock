import type { SdStatusCard } from "./sd-status-card";
import type { SdUpdateCard } from "./sd-update-card";
import type { SdUpstreamDialog } from "./sd-upstream-dialog";
import { applyUpdate, checkUpdate, moduleVersion, readStatus } from "../api";
import { messageOf } from "../errors";
import { notify } from "../notify";
import { currentTheme, initTheme, toggleTheme } from "../theme";
import { requireElement } from "./dom";
import "./sd-autoload-card";
import "./sd-badge";
import "./sd-log-panel";
import "./sd-row";
import "./sd-status-card";
import "./sd-update-card";
import "./sd-upstream-dialog";

const FAIL_REASONS: Partial<Record<number, string>> = {
    1: "拿不到上游信息，或没有匹配本机的驱动。",
    2: "下载失败，请检查网络。",
    3: "驱动校验失败（sha256 不匹配）。",
    4: "写入失败，请检查存储空间与权限。",
};

/*
 * 页面根组件：负责编排状态刷新和更新流程。
 * 页面结构全部写在 index.html，这里只绑事件、写数据。
 */
export class SdApp extends HTMLElement {
    private ready = false;

    connectedCallback(): void {
        if (this.ready) {
            return;
        }
        this.ready = true;

        initTheme();

        const version = moduleVersion();
        if (version !== "") {
            requireElement(this, "#version").textContent = version;
        }

        const themeButton = requireElement<HTMLButtonElement>(this, "#theme");
        themeButton.addEventListener("click", () => {
            toggleTheme();
            this.syncTheme(themeButton);
        });
        this.syncTheme(themeButton);

        requireElement<HTMLButtonElement>(this, "#refresh-status")
            .addEventListener("click", () => void this.refreshStatus());

        const update = requireElement<SdUpdateCard>(this, "sd-update-card");
        update.addEventListener("sd-check", () => void this.detectUpdate());
        update.addEventListener("sd-update", () => void this.installUpdate());

        const upstream = requireElement<SdUpstreamDialog>(this, "sd-upstream-dialog");
        requireElement<HTMLButtonElement>(this, "#upstream-open")
            .addEventListener("click", () => upstream.open());
        this.addEventListener("sd-upstream-changed", () => update.setIdle());

        void this.refreshStatus();
    }

    private syncTheme(button: HTMLButtonElement): void {
        const mode = currentTheme();
        const label = mode === "dark" ? "切换到浅色" : "切换到深色";

        // 图标显示的是"点一下会切到哪"，具体图标由 CSS 按 .dark 选择
        button.title = label;
        button.setAttribute("aria-label", label);
    }

    private async refreshStatus(): Promise<void> {
        const card = requireElement<SdStatusCard>(this, "sd-status-card");

        try {
            card.setStatus(await readStatus());
        }
        catch (error) {
            const message = messageOf(error);
            card.setError(message);
            notify(`读取状态失败：${message}`);
        }
    }

    private async detectUpdate(): Promise<void> {
        const card = requireElement<SdUpdateCard>(this, "sd-update-card");
        card.setBusy("正在查询上游…");

        try {
            const result = await checkUpdate();

            if (result.state === "available") {
                card.setAvailable(result.version);
                return;
            }
            if (result.state === "current") {
                card.setCurrent("");
                return;
            }

            card.setNote(`检测失败：${result.message}`);
        }
        catch (error) {
            card.setNote(`检测失败：${messageOf(error)}`);
        }
    }

    private async installUpdate(): Promise<void> {
        const card = requireElement<SdUpdateCard>(this, "sd-update-card");
        card.setBusy("正在下载并校验…");

        try {
            const result = await applyUpdate();

            if (result.ok) {
                await this.refreshStatus();
                card.setNote("更新完成，重启后生效。");
                notify("更新完成，重启后生效");
                return;
            }

            notify("更新失败");
            card.setFailed(FAIL_REASONS[result.errno] ?? "更新脚本执行失败。", result.log);
        }
        catch (error) {
            card.setFailed(messageOf(error), "");
        }
    }
}

if (!customElements.get("sd-app")) {
    customElements.define("sd-app", SdApp);
}
