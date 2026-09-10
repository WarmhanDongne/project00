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

# 사용자에게는 하나의 Mosigame 앱으로 배포되지만, 코드 경계를 지키기 위해
# 내부 Flutter package로 나눕니다. 이 package들은 런타임 다운로드 대상이 아닙니다.
FIXED_APP_PACKAGES = {
    "game_kit",
}

# 새 게임을 시작할 때 복사하는 스켈레톤입니다. 앱이 의존하지 않으므로
# 번들에도 패치에도 들어가지 않습니다. 역할 검사에서 제외합니다.
TEMPLATE_PACKAGES = {
    "game_template",
}

# ``game_`` 접두사를 쓰지만 실제 게임 구현이 아닌 지원 package 이름입니다.
# game_contract는 현재 game_kit에 통합됐지만, 과거/향후 workspace 입력에서도
# 다운로드 게임으로 오분류하면 안 되는 예약 이름으로 유지합니다.
NON_GAME_IMPLEMENTATION_PACKAGES = (
    FIXED_APP_PACKAGES
    | TEMPLATE_PACKAGES
    | {"game_contract"}
)

# 첫 정식 바이너리에 코드와 에셋을 함께 넣는 기본 게임입니다.
BUNDLED_GAME_PACKAGES = {
    "game_liars_poker",
    "game_final_call",
    "game_mafia",
}

REQUIRED_WORKSPACE_PACKAGES = FIXED_APP_PACKAGES | BUNDLED_GAME_PACKAGES
NATIVE_PLATFORM_DIRS = ("android", "ios", "linux", "macos", "windows")

# from → 의존해도 되는 내부 패키지. 앱 셸은 모든 workspace package를 조립합니다.
ALLOWED = {
    # game_kit 은 앱에 고정 내장되는 유일한 공용 package 입니다.
    # core·contract·kit 을 하나로 합쳤으므로 내부 의존이 없습니다.
    "game_kit": {"game_kit"},
    # 게임 package 는 game_kit 만 봅니다. 서로를 보지 않고 앱도 보지 않습니다.
    "game_liars_poker": {"game_kit", "game_liars_poker"},
    "game_final_call": {"game_kit", "game_final_call"},
    "game_mafia": {"game_kit", "game_mafia"},
    "game_template": {"game_kit", "game_template"},
}

IMPORT = re.compile(r"""^\s*(?:import|export)\s+['\"]package:([^/'\"]+)/""", re.M)
# 앱 lib/ 에 있으면 안 되는 옛 경로입니다.
# lib/platform/ 은 **정상입니다** — 플랫폼은 앱 본체이고 게임 package 는
# 플랫폼을 의존하지 않습니다. core/firebase/게임 코드만 package 로 가야 합니다.
LEGACY_ROOT_PREFIXES = (
    "lib/core/",
    "lib/firebase/",
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
        return {"game_kit", package}
    return {package}


def is_game_implementation_package(package: str) -> bool:
    """예약된 game_* 지원 package를 제외한 실제 게임 package인지 판별합니다."""
    return (package.startswith("game_")
            and package not in NON_GAME_IMPLEMENTATION_PACKAGES)


def declares_flutter_assets(pubspec: pathlib.Path) -> bool:
    """파일 단위 간단 파서로 flutter.assets 선언 유무를 확인합니다."""
    in_flutter = False
    for line in pubspec.read_text(encoding="utf-8").splitlines():
        if line == "flutter:":
            in_flutter = True
            continue
        if in_flutter and line and not line.startswith((" ", "\t")):
            break
        if in_flutter and re.match(r"^  assets\s*:", line):
            return True
    return False


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


def delivery_role_violations(
    root: pathlib.Path,
    package_dirs: dict[str, pathlib.Path],
) -> tuple[set[str], list[tuple[str, str, str, str]]]:
    """앱 고정 모듈·번들 게임·패치 게임의 배포 경계를 검사합니다."""
    violations: list[tuple[str, str, str, str]] = []
    if not (root / "lib" / "main.dart").is_file():
        violations.append(("app", "missing-app-entrypoint", "lib/main.dart", ""))

    downloadable_game_packages = {
        package
        for package in package_dirs
        if is_game_implementation_package(package)
        and package not in BUNDLED_GAME_PACKAGES
    }

    for package, directory in sorted(package_dirs.items()):
        relative_pubspec = f"packages/{package}/pubspec.yaml"
        if (package not in FIXED_APP_PACKAGES
                and package not in TEMPLATE_PACKAGES
                and not is_game_implementation_package(package)):
            violations.append((package, "unknown-package-role", relative_pubspec, ""))
        if (directory / "lib" / "main.dart").is_file():
            violations.append(
                (package, "package-app-entrypoint", f"packages/{package}/lib/main.dart", "")
            )
        if package not in downloadable_game_packages:
            continue
        if declares_flutter_assets(directory / "pubspec.yaml"):
            violations.append(
                (package, "downloadable-game-bundled-assets", relative_pubspec, "")
            )
        generated_assets = directory / "lib" / "gen" / "assets.gen.dart"
        if generated_assets.is_file():
            violations.append(
                (
                    package,
                    "downloadable-game-generated-assets",
                    generated_assets.relative_to(root).as_posix(),
                    "",
                )
            )
        for platform in NATIVE_PLATFORM_DIRS:
            native_dir = directory / platform
            if native_dir.is_dir():
                violations.append(
                    (
                        package,
                        "downloadable-game-native-code",
                        native_dir.relative_to(root).as_posix(),
                        platform,
                    )
                )

    return downloadable_game_packages, violations


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
    missing = sorted(REQUIRED_WORKSPACE_PACKAGES - package_dirs.keys())
    if missing:
        print(f"필수 workspace package 누락: {', '.join(missing)}", file=sys.stderr)
        return 2

    internal_packages = set(package_dirs) | {APP_PACKAGE}
    counts = collections.Counter()
    downloadable_game_packages, violations = delivery_role_violations(
        root,
        package_dirs,
    )

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

    print("=== 배포 역할 ===")
    print(f"  고정 앱 모듈       {', '.join(sorted(FIXED_APP_PACKAGES))}")
    print(f"  기본 번들 게임     {', '.join(sorted(BUNDLED_GAME_PACKAGES))}")
    print(
        "  패치 추가 게임     "
        + (", ".join(sorted(downloadable_game_packages)) or "(없음)")
    )

    print("\n=== 물리 패키지별 Dart 파일 수 ===")
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
