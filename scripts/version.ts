const NUMERIC = /^\d+$/;

export function parseVersion(version: string) {
    if (typeof version !== "string")
        throw new Error("version must be a string");

    const versionParts = version.split(".");

    if (versionParts.length !== 3)
        throw new Error("version must be in the format {major}.{minor}.{patch}");

    const nums = versionParts.map(part => {
        if (!NUMERIC.test(part))
            throw new Error(`version part "${part}" must be a non-negative integer`);
        return Number(part);
    });

    const [major, minor, patch] = nums;

    if (minor > 99 || patch > 99)
        throw new Error("minor and patch must be <= 99 to avoid versionCode overflow");

    const versionCode = major * 10000 + minor * 100 + patch;

    return { major, minor, patch, versionCode };
}

if (import.meta.main) {
    const packageJson = await import("../package.json", { with: { type: "json" } });
    const version = packageJson.default.version;
    const { versionCode } = parseVersion(version);
    console.log(version, versionCode);
}
