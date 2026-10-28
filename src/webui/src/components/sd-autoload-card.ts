import { readAutoload, setAutoload } from "../api";
import { messageOf } from "../errors";
import { notify } from "../notify";
import { requireElement } from "./dom";

/*
 * 开机加载开关。状态来自 post-fs-data.d/ 里的脚本是否存在，
 * 切换失败时把勾选状态改回去，避免界面和实际不一致。
 */
export class SdAutoloadCard extends HTMLElement {
    private ready = false;
    private busy = false;

    connectedCallback(): void {
        if (this.ready) {
            return;
        }
        this.ready = true;

        requireElement<HTMLInputElement>(this, "#autoload-toggle")
            .addEventListener("change", () => void this.toggle());

        void this.load();
    }

    private async load(): Promise<void> {
        const toggle = requireElement<HTMLInputElement>(this, "#autoload-toggle");

        try {
            const enabled = await readAutoload();
            toggle.checked = enabled;
            this.setMeta(enabled);
        }
        catch (error) {
            toggle.checked = false;
            this.meta().textContent = `读取失败：${this.describe(error)}`;
        }
    }

    private async toggle(): Promise<void> {
        if (this.busy) {
            return;
        }
        this.busy = true;

        const toggle = requireElement<HTMLInputElement>(this, "#autoload-toggle");
        const wanted = toggle.checked;
        toggle.disabled = true;

        try {
            const enabled = await setAutoload(wanted);
            toggle.checked = enabled;
            this.setMeta(enabled);
            notify(enabled ? "已开启开机加载" : "已关闭开机加载");
        }
        catch (error) {
            toggle.checked = !wanted;
            const message = this.describe(error);
            this.meta().textContent = `切换失败：${message}`;
            notify(`切换失败：${message}`);
        }
        finally {
            toggle.disabled = false;
            this.busy = false;
        }
    }

    // entry.sh 在模块被禁用时统一报 "module is disabled"，这里换成可读提示
    private describe(error: unknown): string {
        const message = messageOf(error);
        return message.includes("module is disabled")
            ? "模块已被禁用，无法修改开机加载。"
            : message;
    }

    private setMeta(enabled: boolean): void {
        this.meta().textContent = enabled
            ? "已开启，重启后由 post-fs-data.d 优先加载。"
            : "已关闭，由模块的 post-fs-data.sh 加载。";
    }

    private meta(): HTMLElement {
        return requireElement(this, "#autoload-meta");
    }
}

if (!customElements.get("sd-autoload-card")) {
    customElements.define("sd-autoload-card", SdAutoloadCard);
}
