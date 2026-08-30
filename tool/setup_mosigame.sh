#!/usr/bin/env bash

set -u

prepare=false
targeted=none
full=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --prepare)
      prepare=true
      shift
      ;;
    --targeted)
      if [ "$#" -lt 2 ]; then
        echo "BLOCKED — --targeted requires session or auth." >&2
        exit 2
      fi
      targeted="$2"
      shift 2
      ;;
    --full)
      full=true
      shift
      ;;
    *)
      echo "BLOCKED — unknown option: $1" >&2
      exit 2
      ;;
  esac
done

if [ "$targeted" != "none" ] && [ "$targeted" != "session" ] && [ "$targeted" != "auth" ]; then
  echo "BLOCKED — targeted suite must be session or auth." >&2
  exit 2
fi

if [ "$(uname -s)" != "Darwin" ]; then
  echo "BLOCKED — tool/setup_mosigame.sh supports macOS only." >&2
  exit 3
fi

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
repository_root="$(dirname -- "$script_dir")"
cd "$repository_root" || exit 3

for command in git flutter dart node npm java adb xcodebuild pod; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "BLOCKED — $command is unavailable. Install or select it manually." >&2
    exit 3
  fi
done

java_version="$(java -version 2>&1 | head -n 1)"
java_major="$(printf '%s' "$java_version" | sed -E 's/.*"([0-9]+).*/\1/')"
if ! printf '%s' "$java_major" | grep -Eq '^[0-9]+$' || [ "$java_major" -lt 17 ]; then
  echo "BLOCKED — Java 17 or newer is required." >&2
  exit 3
fi

before_status="$(git status --porcelain=v2 --branch --untracked-files=all)" || {
  echo "BLOCKED — Git working-tree state could not be read." >&2
  exit 3
}

required_files="
AGENTS.md
docs/engineering/ENGINEERING_CONTRACT.md
docs/engineering/PROJECT_CLI.md
pubspec.yaml
.nvmrc
functions/package.json
functions/package-lock.json
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
lib/firebase/firebase_options.dart
"
while IFS= read -r required_file; do
  [ -z "$required_file" ] && continue
  if [ ! -f "$required_file" ]; then
    echo "BLOCKED — required repository file is missing: $required_file" >&2
    exit 3
  fi
done <<EOF
$required_files
EOF

expected_node_major="$(tr -d '[:space:]' < .nvmrc)"
actual_node="$(node --version)" || exit 3
actual_node_major="$(printf '%s' "$actual_node" | sed -E 's/^v?([0-9]+).*/\1/')"
if [ "$actual_node_major" != "$expected_node_major" ]; then
  echo "BLOCKED — Node.js major $actual_node_major does not match .nvmrc $expected_node_major." >&2
  exit 3
fi

if ! xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
  echo "BLOCKED — Xcode first-launch tasks or license require user action." >&2
  exit 3
fi

echo "OS: macos"
if [ "$prepare" = true ]; then
  echo "Setup mode: prepare"
  flutter pub get || exit $?
  (cd functions && npm ci) || exit $?
else
  echo "Setup mode: audit"
  if [ ! -f .dart_tool/package_config.json ] || [ ! -d functions/node_modules ]; then
    echo "BLOCKED — repository dependencies are incomplete. Re-run with --prepare after approval." >&2
    exit 3
  fi
fi

dart run :mosigame doctor || exit $?

if [ "$targeted" != "none" ]; then
  dart run :mosigame test "$targeted" || exit $?
fi

if [ "$full" = true ]; then
  dart run :mosigame validate --full || exit $?
fi

after_status="$(git status --porcelain=v2 --branch --untracked-files=all)" || exit 3
if [ "$after_status" != "$before_status" ]; then
  echo "BLOCKED — Git working-tree state changed. Inspect the diff; nothing was restored." >&2
  exit 1
fi

echo "READY — MOSIGAME DEVELOPMENT ENVIRONMENT"
if [ "$targeted" = "none" ]; then
  echo "Targeted: NOT RUN"
else
  echo "Targeted: PASS"
fi
if [ "$full" = true ]; then
  echo "FULL: PASS"
else
  echo "FULL: NOT RUN"
fi
echo "Working tree: preserved"
