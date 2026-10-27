// 主题：在 <html> 上挂/摘 .dark，选择记在 localStorage。
// 没存过就跟随系统第一次的偏好，之后以用户的选择为准。

const KEY = "theme";

export type ThemeMode = "dark" | "light";

function stored(): ThemeMode | null {
    try {
        const value = localStorage.getItem(KEY);
        return value === "dark" || value === "light" ? value : null;
    }
    catch {
        // 隐私模式等场合读不了，当作没存过
        return null;
    }
}

function save(mode: ThemeMode): void {
    try {
        localStorage.setItem(KEY, mode);
    }
    catch {
        // 存不了就算了，本次会话内仍然生效
    }
}

function systemPrefers(): ThemeMode {
    return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
}

function apply(mode: ThemeMode): void {
    document.documentElement.classList.toggle("dark", mode === "dark");
}

export function initTheme(): void {
    apply(stored() ?? systemPrefers());
}

export function currentTheme(): ThemeMode {
    return document.documentElement.classList.contains("dark") ? "dark" : "light";
}

export function toggleTheme(): ThemeMode {
    const next: ThemeMode = currentTheme() === "dark" ? "light" : "dark";
    apply(next);
    save(next);
    return next;
}
