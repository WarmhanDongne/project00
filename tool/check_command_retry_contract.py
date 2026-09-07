#!/usr/bin/env python3
"""자동 재시도 명령이 안정적인 멱등 키를 보내는지 검사합니다."""

from pathlib import Path
import re
import sys


RETRY = re.compile(r"retryTransientFailure\s*:\s*true")
KEY = re.compile(r"['\"](?:commandId|interruptionId)['\"]\s*:")


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    failures: list[str] = []
    for path in sorted((root / "lib" / "games").rglob("*.dart")):
        source = path.read_text(encoding="utf-8")
        for match in RETRY.finditer(source):
            line_start = source.rfind("\n", 0, match.start()) + 1
            if source[line_start:match.start()].lstrip().startswith("///"):
                continue
            invoke_start = source.rfind("invoke(", 0, match.start())
            block = source[invoke_start:match.start()] if invoke_start >= 0 else ""
            if not KEY.search(block):
                line = source.count("\n", 0, match.start()) + 1
                failures.append(f"{path.relative_to(root)}:{line}")

    if failures:
        print("멱등 키 없는 자동 재시도:", file=sys.stderr)
        for failure in failures:
            print(f"  {failure}", file=sys.stderr)
        return 1
    print("자동 재시도 계약 통과: 모든 호출에 commandId/interruptionId가 있습니다.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
