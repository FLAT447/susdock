import type { LogLevel } from "../api";
import { clearLog, readLog, readLogLevel, setLogLevel } from "../api";
import { messageOf } from "../errors";
import { notify } from "../notify";
import { requireElement } from "./dom";

const AUTO_MS = 5000;
const LOG_LINES = 300;

function clock(): string {
    return new Date().toLocaleTimeString("zh-CN", { hour12: false });
}

// 倒序：最新的一行在最上面
function reverseLines(text: string): string {
    const out: string[] = [];

    // unshift 避免依赖 Array#reverse / toReversed，老 WebView 也能跑
    for (const line of text.replace(/\n+$/, "").split("\n")) {
        out.unshift(line);
    }

    return out.join("\n");
}

/*
 * 日志面板：预览、清空、调节等级。
 * 等级改动要等下一次命令执行才生效，所以这里只提示，不刷新当前日志。
 */
export class SdLogPanel extends HTMLElement {
    private timer: number | null = null;
    private auto = true;
    private reverse = false;
    private loading = false;
    private ready = false;

    connectedCallback(): void {
        if (this.ready) {
            return;
        }
        this.ready = true;

        requireElement(this, "#log-refresh").addEventListener("click", () => void this.refresh());
        requireElement(this, "#log-clear").addEventListener("click", () => void this.clear());
        requireElement(this, "#log-auto").addEventListener("click", () => this.toggleAuto());
        requireElement(this, "#log-order").addEventListener("click", () => this.toggleOrder());
        requireElement<HTMLSelectElement>(this, "#log-level")
            .addEventListener("change", () => void this.changeLevel());

        void this.loadLevel();
        void this.refresh();
        this.startAuto();
    }

    disconnectedCallback(): void {
        this.stopAuto();
    }

    private async refresh(jumpToEnd = false): Promise<void> {
        if (this.loading) {
            return;
        }
        this.loading = true;

        const log = requireElement<HTMLElement>(this, "#log-output");
        const meta = requireElement(this, "#log-meta");

        try {
            const text = await readLog(LOG_LINES);
            const trimmed = text.trim();

            // 正序时新日志在底部，倒序时在顶部；只有原本就贴在那一端才跟着滚
            const pinned = this.reverse
                ? log.scrollTop <= 8
                : log.scrollTop + log.clientHeight >= log.scrollHeight - 8;

            let display = text;
            if (trimmed === "") {
                display = "（日志为空）";
            }
            else if (this.reverse) {
                display = reverseLines(text);
            }
            log.textContent = display;

            if (jumpToEnd || pinned) {
                log.scrollTop = this.reverse ? 0 : log.scrollHeight;
            }

            const count = trimmed === "" ? 0 : trimmed.split("\n").length;
            meta.textContent = `最后更新 ${clock()} · ${count} 行`;
        }
        catch (error) {
            log.textContent = `读取日志失败：${messageOf(error)}`;
            meta.textContent = `最后更新 ${clock()}`;
        }
        finally {
            this.loading = false;
        }
    }

    private async clear(): Promise<void> {
        try {
            await clearLog();
            await this.refresh();
            notify("日志已清空");
        }
        catch (error) {
            notify(`清空日志失败：${messageOf(error)}`);
        }
    }

    private async loadLevel(): Promise<void> {
        try {
            const level = await readLogLevel();
            requireElement<HTMLSelectElement>(this, "#log-level").value = level;
        }
        catch {
            // 读不到就保留默认选项
        }
    }

    private async changeLevel(): Promise<void> {
        const select = requireElement<HTMLSelectElement>(this, "#log-level");
        const level = select.value as LogLevel;

        try {
            const applied = await setLogLevel(level);
            select.value = applied;
            notify(`日志等级已设为 ${applied}，下次执行生效`);
        }
        catch (error) {
            notify(`设置日志等级失败：${messageOf(error)}`);
            await this.loadLevel();
        }
    }

    private toggleOrder(): void {
        this.reverse = !this.reverse;
        requireElement(this, "#log-order").textContent = `排序：${this.reverse ? "倒序" : "正序"}`;
        void this.refresh(true);
    }

    private toggleAuto(): void {
        this.auto = !this.auto;
        requireElement(this, "#log-auto").textContent = `自动刷新：${this.auto ? "开" : "关"}`;

        if (this.auto) {
            this.startAuto();
        }
        else {
            this.stopAuto();
        }
    }

    private startAuto(): void {
        this.stopAuto();
        this.timer = window.setInterval(() => void this.refresh(), AUTO_MS);
    }

    private stopAuto(): void {
        if (this.timer !== null) {
            window.clearInterval(this.timer);
            this.timer = null;
        }
    }
}

if (!customElements.get("sd-log-panel")) {
    customElements.define("sd-log-panel", SdLogPanel);
}
