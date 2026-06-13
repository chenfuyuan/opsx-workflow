#!/usr/bin/env python3
"""Stop hook: 测试基线门（opt-in）。

启用方式：在 .claude/hooks/test-command 写入一行测试命令
（参考 test-command.example）。未配置该文件时本 hook 完全静默。

行为：
- 仅当本次会话存在未提交的"代码改动"时才跑测试
  （只改了 *.md / openspec/ / .claude/ 视为规划回合，跳过）。
- 测试失败 → exit 2 拦截结束，把失败摘要喂回 Claude 继续修。
- stop_hook_active 防死循环：上一次拦截后的再次结束直接放行。
- 测试超时 → 放行但打印警告（挂死的测试套件不应锁死会话）。
"""
import json
import os
import subprocess
import sys

INTERNAL_TIMEOUT = 540  # 秒；settings.json 外层 timeout 为 600


def changed_files(project_dir: str):
    try:
        r = subprocess.run(
            ["git", "status", "--porcelain"],
            capture_output=True, text=True, timeout=15, cwd=project_dir,
        )
        if r.returncode != 0:
            return None  # 不是 git 仓库等情况：返回 None 表示"无法判断"
        files = []
        for line in r.stdout.splitlines():
            if len(line) > 3:
                f = line[3:].strip().strip('"')
                if " -> " in f:  # rename
                    f = f.split(" -> ")[-1]
                files.append(f)
        return files
    except Exception:
        return None


def is_planning_only(files) -> bool:
    if files is None:
        return False  # 判断不了就保守地跑测试
    if not files:
        return True   # 工作区干净：无需测试
    for f in files:
        norm = f.replace("\\", "/")
        if norm.startswith("openspec/") or norm.startswith(".claude/"):
            continue
        if norm.endswith(".md"):
            continue
        return False
    return True


def main() -> int:
    try:
        data = json.load(sys.stdin)
    except Exception:
        data = {}

    if data.get("stop_hook_active"):
        return 0  # 防死循环

    project_dir = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    cmd_file = os.path.join(project_dir, ".claude", "hooks", "test-command")
    if not os.path.isfile(cmd_file):
        return 0
    with open(cmd_file, "r", encoding="utf-8") as fh:
        lines = [l.strip() for l in fh.readlines()]
    cmd = next((l for l in lines if l and not l.startswith("#")), "")
    if not cmd:
        return 0

    if is_planning_only(changed_files(project_dir)):
        return 0

    try:
        r = subprocess.run(
            cmd, shell=True, capture_output=True, text=True,
            timeout=INTERNAL_TIMEOUT, cwd=project_dir,
        )
    except subprocess.TimeoutExpired:
        print(f"[test_baseline] 测试命令超时（>{INTERNAL_TIMEOUT}s），本次放行。", file=sys.stderr)
        return 0
    except Exception as e:
        print(f"[test_baseline] 测试命令无法执行（{e}），本次放行。", file=sys.stderr)
        return 0

    if r.returncode != 0:
        tail = ((r.stdout or "") + "\n" + (r.stderr or ""))[-2000:]
        print(
            f"测试基线未通过（Stop 门拦截）。命令：{cmd}\n"
            f"--- 输出尾部 ---\n{tail}\n"
            "请修复失败的测试后再结束回合。若失败与本回合改动确实无关，"
            "请在回复中向用户说明原因后再次结束（第二次结束不会被拦截）。",
            file=sys.stderr,
        )
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
