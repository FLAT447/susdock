import { requireElement } from "./dom";
import "./sd-badge";

type View = "available" | "busy" | "current" | "failed" | "idle" | "note";

/*
 * 更新卡：只负责显示和发事件，具体请求由 sd-app 处理。
 * 事件：sd-check（开始检测）、sd-update（执行更新）
 * 视图 DOM 全部来自 index.html，用 data-view 标记。
 */
export class SdUpdateCard extends HTMLElement {
    private ready = false;

    connectedCallback(): void {
        if (this.ready) {
            return;
        }
        this.ready = true;

        // 事件委托：所有按钮都带 data-action，隐藏视图里的按钮也能正常响应
        this.addEventListener("click", event => {
            const target = event.target;
            if (!(target instanceof Element)) {
                return;
            }

            const action = target.closest<HTMLElement>("[data-action]")?.dataset.action;

            if (action === "check") {
                this.emit("sd-check");
            }
            else if (action === "update") {
                this.emit("sd-update");
            }
        });
    }

    setIdle(): void {
        this.show("idle");
    }

    setBusy(text: string): void {
        requireElement(this, ".busy-text").textContent = text;
        this.show("busy");
    }

    setAvailable(version: string): void {
        requireElement(this, "[data-role=\"available-tag\"]").textContent = version;
        this.show("available");
    }

    setCurrent(version: string): void {
        const tag = requireElement(this, "[data-role=\"current-tag\"]");
        tag.textContent = version;
        tag.hidden = version === "";
        this.show("current");
    }

    setFailed(reason: string, log: string): void {
        requireElement(this, "[data-role=\"reason\"]").textContent = reason;
        requireElement(this, "[data-role=\"log\"]").textContent = log;
        this.show("failed");
    }

    setNote(text: string): void {
        requireElement(this, "[data-role=\"note\"]").textContent = text;
        this.show("note");
    }

    private show(view: View): void {
        for (const section of this.querySelectorAll<HTMLElement>("[data-view]")) {
            section.hidden = section.dataset.view !== view;
        }
    }

    private emit(name: string): void {
        this.dispatchEvent(new CustomEvent(name, { bubbles: true, composed: true }));
    }
}

if (!customElements.get("sd-update-card")) {
    customElements.define("sd-update-card", SdUpdateCard);
}
