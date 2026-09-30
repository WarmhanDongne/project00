#!/usr/bin/env python3
"""Package delivery-role boundary regression tests."""

import pathlib
import tempfile
import unittest

from check_package_boundaries import (
    declares_flutter_assets,
    delivery_role_violations,
    file_naming_violations,
    is_game_implementation_package,
)


class PackageDeliveryBoundaryTest(unittest.TestCase):
    def test_device_board_exception_does_not_allow_other_repeated_names(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            game = root / "packages" / "game_sample"
            for relative in ("phone/phone_board.dart", "tablet/tablet_board.dart",
                             "phone/widgets/phone_card.dart", "phone/widgets/phone_board.dart"):
                file = game / "lib" / relative
                file.parent.mkdir(parents=True, exist_ok=True)
                file.write_text("// fixture\n", encoding="utf-8")
            violations = file_naming_violations(root, {"game_sample": game})
            self.assertEqual(len(violations), 2)
            self.assertTrue(all("/widgets/" in item[2] for item in violations))

    def test_fixed_game_support_packages_are_not_game_implementations(self) -> None:
        self.assertFalse(is_game_implementation_package("game_contract"))
        self.assertFalse(is_game_implementation_package("game_kit"))
        self.assertTrue(is_game_implementation_package("game_future_round"))

    def test_detects_flutter_assets_only_inside_flutter_section(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            pubspec = pathlib.Path(temp) / "pubspec.yaml"
            pubspec.write_text(
                "name: sample\nflutter:\n  assets:\n    - assets/\n",
                encoding="utf-8",
            )
            self.assertTrue(declares_flutter_assets(pubspec))

            pubspec.write_text(
                "name: sample\ndependencies:\n  assets: any\nflutter:\n  uses-material-design: true\n",
                encoding="utf-8",
            )
            self.assertFalse(declares_flutter_assets(pubspec))

    def test_downloadable_game_rejects_bundled_assets_and_native_code(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            (root / "lib").mkdir()
            (root / "lib" / "main.dart").write_text("void main() {}\n", encoding="utf-8")
            game_dir = root / "packages" / "game_future_round"
            (game_dir / "lib" / "gen").mkdir(parents=True)
            (game_dir / "ios").mkdir()
            (game_dir / "pubspec.yaml").write_text(
                "name: game_future_round\nflutter:\n  assets:\n    - assets/\n",
                encoding="utf-8",
            )
            (game_dir / "lib" / "gen" / "assets.gen.dart").write_text(
                "// generated\n",
                encoding="utf-8",
            )

            downloadable, violations = delivery_role_violations(
                root,
                {"game_future_round": game_dir},
            )

            self.assertEqual(downloadable, {"game_future_round"})
            self.assertEqual(
                {kind for _, kind, _, _ in violations},
                {
                    "downloadable-game-bundled-assets",
                    "downloadable-game-generated-assets",
                    "downloadable-game-native-code",
                },
            )

    def test_platform_is_a_library_module_not_an_app_entrypoint(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            (root / "lib").mkdir()
            (root / "lib" / "main.dart").write_text("void main() {}\n", encoding="utf-8")
            platform_dir = root / "packages" / "mosigame_platform"
            (platform_dir / "lib").mkdir(parents=True)
            (platform_dir / "lib" / "main.dart").write_text(
                "void main() {}\n",
                encoding="utf-8",
            )
            (platform_dir / "pubspec.yaml").write_text(
                "name: mosigame_platform\n",
                encoding="utf-8",
            )

            _, violations = delivery_role_violations(
                root,
                {"mosigame_platform": platform_dir},
            )

            self.assertIn(
                "package-app-entrypoint",
                {kind for _, kind, _, _ in violations},
            )

    def test_rejects_repeated_package_and_device_names(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            package_dir = root / "packages" / "game_final_call"
            phone_dir = package_dir / "lib" / "screens" / "phone"
            phone_dir.mkdir(parents=True)
            (package_dir / "pubspec.yaml").write_text(
                "name: game_final_call\n",
                encoding="utf-8",
            )
            (package_dir / "lib" / "final_call_controller.dart").write_text(
                "// repeated package name\n",
                encoding="utf-8",
            )
            (phone_dir / "phone_game_screen.dart").write_text(
                "// repeated device name\n",
                encoding="utf-8",
            )
            (phone_dir / "game_screen.dart").write_text(
                "// valid\n",
                encoding="utf-8",
            )
            generated_dir = package_dir / "lib" / "gen"
            generated_dir.mkdir()
            (generated_dir / "final_call_assets.gen.dart").write_text(
                "// generated exception\n",
                encoding="utf-8",
            )

            violations = file_naming_violations(
                root,
                {"game_final_call": package_dir},
            )

            self.assertEqual(
                {kind for _, kind, _, _ in violations},
                {"repeated-package-name", "repeated-device-name"},
            )

    def test_allows_device_name_without_a_device_folder(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            package_dir = root / "packages" / "game_final_call"
            screens_dir = package_dir / "lib" / "screens"
            screens_dir.mkdir(parents=True)
            (package_dir / "pubspec.yaml").write_text(
                "name: game_final_call\n",
                encoding="utf-8",
            )
            (screens_dir / "phone_game.dart").write_text(
                "// phone and tablet files share this directory\n",
                encoding="utf-8",
            )

            violations = file_naming_violations(
                root,
                {"game_final_call": package_dir},
            )

            self.assertEqual(violations, [])


if __name__ == "__main__":
    unittest.main()
