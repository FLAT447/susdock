import { toast } from "kernelsu";

// 非 KernelSU 环境下没有 toast，调用会抛错，这里统一吞掉
export function notify(message: string): void {
    try {
        toast(message);
    }
    catch {
        // 忽略：通知不是关键路径
    }
}
