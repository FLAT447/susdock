/*
 * 用法：<sd-badge tone="ok|fail|new">文字</sd-badge>
 * 样式在 stylesheet.css，组件只负责把 tone 暴露成属性。
 */
export class SdBadge extends HTMLElement {
    get tone(): string {
        return this.getAttribute("tone") ?? "";
    }

    set tone(value: string) {
        if (value === "") {
            this.removeAttribute("tone");
            return;
        }

        this.setAttribute("tone", value);
    }
}

if (!customElements.get("sd-badge")) {
    customElements.define("sd-badge", SdBadge);
}
