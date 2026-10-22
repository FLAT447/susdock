import { styleText } from "node:util";

export enum Types {
    detail,
    error,
    info,
    success,
    warn,
};

type Format = Parameters<typeof styleText>[0];

const STYLES: Record<Types, Format> = {
    [Types.info]: "blue",
    [Types.success]: "green",
    [Types.warn]: "yellow",
    [Types.error]: ["red", "bold"],
    [Types.detail]: "dim",
};

const LABELS: Record<Types, string> = {
    [Types.info]: "INFO",
    [Types.success]: " OK ",
    [Types.warn]: "WARN",
    [Types.error]: "FAIL",
    [Types.detail]: "  · ",
};

function timestamp(): string {
    const d = new Date();
    const hh = String(d.getHours()).padStart(2, "0");
    const mm = String(d.getMinutes()).padStart(2, "0");
    const ss = String(d.getSeconds()).padStart(2, "0");
    const ms = String(d.getMilliseconds()).padStart(3, "0");
    return `${hh}:${mm}:${ss}.${ms}`;
}

export function log(msg: string, type: Types = Types.info): void {
    const time = styleText("dim", timestamp());
    const label = styleText(STYLES[type], LABELS[type]);
    const text = styleText(STYLES[type], msg);

    const out = `${time} ${label} ${text}`;

    if (type === Types.error)
        console.error(out);
    else
        console.log(out);
}
