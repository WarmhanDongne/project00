#!/usr/bin/env python3
"""Mosigame workspace의 물리 패키지 경계를 검증합니다.

루트 앱과 ``packages/*/lib``를 모두 스캔해 내부 package import 방향,
workspace pubspec 의존성, 루트에 되살아난 레거시 소스 경로를 검사합니다.

    python3 tool/check_package_boundaries.py
    python3 tool/check_package_boundaries.py --detail
    python3 tool/check_package_boundaries.py --max 0
"""

import argparse
import collections
import pathlib
import re
import sys

APP_PACKAGE = "project00"
WORKSPACE_PACKAGES = {
    "mosigame_core",
    "game_contract",
    "game_kit",
    "mosigame_platform",
    "game_liars_poker",
    "game_final_call",
    "game_mafia",
}

# from → 의존해도 되는 내부 패키지. 앱 셸은 모든 workspace package를 조립합니다.
ALLOWED = {
    "mosigame_core": {"mosigame_core"},
    "game_contract": {"mosigame_core", "game_contract"},
    "game_kit": {"mosigame_core", "game_contract", "game_kit"},
    "mosigame_platform": {
        "mosigame_core",
        "game_contract",
        "mosigame_platform",
    },
    "game_liars_poker": {
        "mosigame_core",
        "game_contract",
        "game_kit",
        "game_liars_poker",
    },
    "game_final_call": {
        "mosigame_core",
        "game_contract",
        "game_kit",
        "game_final_call",
    },
    "game_mafia": {
        "mosigame_core",
        "game_contract",
        "game_kit",
        "game_mafia",
    },
}

IMPORT = re.compile(r"""^\s*(?:import|export)\s+['\"]package:([^/'\"]+)/""", re.M)
LEGACY_ROOT_PREFIXES = (
    "lib/core/",
    "lib/firebase/",
    "lib/platform/",
    "lib/games/_game_template/",
    "lib/games/final_call/",
    "lib/games/liars_poker/",
    "lib/games/mafia/",
    "lib/games/penalty/",
    "lib/games/shared/",
)


def allowed_for(package: str) -> set[str]:
    """기존 게임과 이후 추가될 game_* 패키지에 같은 방향 규칙을 적용합니다."""
    if package in ALLOWED:
        return ALLOWED[package]
    if package.startswith("game_"):
        return {"mosigame_core", "game_contract", "game_kit", package}
    return {package}


def dependency_names(pubspec: pathlib.Path) -> set[str]:
    """외부 YAML 의존성 없이 dependencies의 최상위 key만 읽습니다."""
    result: set[str] = set()
    in_dependencies = False
    for line in pubspec.read_text(encoding="utf-8").splitlines():
        if line == "dependencies:":
            in_dependencies = True
            continue
        if in_dependencies and line and not line.startswith((" ", "\t")):
            break
        if not in_dependencies:
            continue
        match = re.match(r"^  ([A-Za-z0-9_]+):", line)
        if match:
            result.add(match.group(1))
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--detail", action="store_true", help="위반 파일 경로까지 출력")
    parser.add_argument("--max", type=int, default=None, help="허용 위반 수. 초과하면 exit 1")
    args = parser.parse_args()

    root = pathlib.Path(__file__).resolve().parent.parent
    if not (root / "lib").is_dir() or not (root / "packages").is_dir():
        print("workspace lib/ 또는 packages/를 찾지 못했습니다.", file=sys.stderr)
        return 2

    package_dirs = {
        path.parent.name: path.parent
        for path in sorted((root / "packages").glob("*/pubspec.yaml"))
    }
    missing = sorted(WORKSPACE_PACKAGES - package_dirs.keys())
    if missing:
        print(f"필수 workspace package 누락: {', '.join(missing)}", file=sys.stderr)
        return 2

    internal_packages = set(package_dirs) | {APP_PACKAGE}
    counts = collections.Counter()
    violations: list[tuple[str, str, str, str]] = []

    sources = [("app", root / "lib")]
    sources.extend((name, directory / "lib") for name, directory in package_dirs.items())
    for source, lib_dir in sources:
        if not lib_dir.is_dir():
            violations.append((source, "missing-lib", lib_dir.relative_to(root).as_posix(), ""))
            continue
        declared = (
            internal_packages
            if source == "app"
            else dependency_names(package_dirs[source] / "pubspec.yaml") | {source}
        )
        allowed = internal_packages if source == "app" else allowed_for(source)
        for file in sorted(lib_dir.rglob("*.dart")):
            relative = file.relative_to(root).as_posix()
            counts[source] += 1
            for imported in IMPORT.findall(file.read_text(encoding="utf-8")):
                if imported not in internal_packages:
                    continue
                if source == "app":
                    continue
                target = "app" if imported == APP_PACKAGE else imported
                if imported == APP_PACKAGE or target not in allowed:
                    violations.append((source, target, relative, imported))
                elif target not in declared:
                    violations.append((source, "undeclared-dependency", relative, imported))

    for file in sorted((root / "lib").rglob("*.dart")):
        relative = file.relative_to(root).as_posix()
        if relative.startswith(LEGACY_ROOT_PREFIXES):
            violations.append(("app", "legacy-root-source", relative, ""))

    for source, directory in sorted(package_dirs.items()):
        declared = dependency_names(directory / "pubspec.yaml")
        for target in sorted((declared & set(package_dirs)) - allowed_for(source)):
            violations.append(
                (source, "forbidden-pubspec-dependency", f"packages/{source}/pubspec.yaml", target)
            )

    print("=== 물리 패키지별 Dart 파일 수 ===")
    for package, count in sorted(counts.items(), key=lambda item: (-item[1], item[0])):
        print(f"  {package:<20} {count:>4}")

    grouped = collections.defaultdict(list)
    for source, kind, path, target in violations:
        grouped[(source, kind)].append((path, target))
    print(f"\n=== 경계 위반 {len(violations)}건 ===")
    for (source, kind), items in sorted(grouped.items()):
        print(f"\n  {source}  --X-->  {kind}   ({len(items)}건)")
        for path, target in items if args.detail else items[:8]:
            suffix = f" -> {target}" if target else ""
            print(f"      {path}{suffix}")
        if not args.detail and len(items) > 8:
            print(f"      ... {len(items) - 8}건 더 있음 (--detail)")

    if not violations:
        print("\n  위반 없음 — source, import, pubspec 경계가 일치합니다.")

    if args.max is not None and len(violations) > args.max:
        print(
            f"\n실패: 위반 {len(violations)}건 > 허용 {args.max}건",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
