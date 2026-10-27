/*
 * 用法：
 *   <sd-row data-field="android">
 *       <span class="row-k">Android</span>
 *       <span class="row-v">-</span>
 *   </sd-row>
 * 结构写在 index.html，组件只负责更新右侧的值。
 */
export class SdRow extends HTMLElement {
    get value(): string {
        return this.querySelector(".row-v")?.textContent ?? "";
    }

    set value(text: string) {
        const node = this.querySelector(".row-v");
        if (node !== null) {
            node.textContent = text;
        }
    }
}

if (!customElements.get("sd-row")) {
    customElements.define("sd-row", SdRow);
}
