#!/usr/bin/env python3
"""PreToolUse hook: 阻止对 openspec/changes/archive/** 的写入。

多个 OPSX 命令承诺"不在 archive/ 下创建或修改 change"——本 hook 把这条
从建议级提升为确定性拦截（覆盖 Edit / MultiEdit / Write / NotebookEdit）。

退出码约定（Claude Code hooks）：
  0 = 放行；2 = 拦截（stderr 会反馈给 Claude）。
注意：本 hook 不拦截 Bash（如 mv/cp）——/opsx:archive 本身需要用 Bash
移动目录进 archive，这是预期内的逃生口。
"""
import json
import sys


def main() -> int:
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0  # 解析失败时放行，避免误伤

    tool_input = data.get("tool_input") or {}
    path = tool_input.get("file_path") or tool_input.get("path") or ""
    if not path:
        return 0

    norm = str(path).replace("\\", "/")
    if "openspec/changes/archive/" in norm:
        print(
            "已拦截：禁止直接编辑已归档的 change（openspec/changes/archive/**）。\n"
            "归档内容是历史事实源。若确需修改：(a) 新开一个 change 走正常流程；"
            "(b) 或由用户在 Claude 之外手动操作。",
            file=sys.stderr,
        )
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
