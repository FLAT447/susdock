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
            this.meta().textContent = `读取失败：${messageOf(error)}`;
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
            const message = messageOf(error);
            this.meta().textContent = `切换失败：${message}`;
            notify(`切换失败：${message}`);
        }
        finally {
            toggle.disabled = false;
            this.busy = false;
        }
    }

    private setMeta(enabled: boolean): void {
        this.meta().textContent = enabled
            ? "已开启，重启后自动加载驱动。"
            : "已关闭，重启后不会自动加载。";
    }

    private meta(): HTMLElement {
        return requireElement(this, "#autoload-meta");
    }
}

if (!customElements.get("sd-autoload-card")) {
    customElements.define("sd-autoload-card", SdAutoloadCard);
}
