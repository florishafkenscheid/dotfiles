import importlib.util
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import tomllib
import unittest


DESKTOP = Path(__file__).resolve().parents[1]
ROOT = DESKTOP.parents[1]
CATALOG = DESKTOP / "themes/catalog.json"
spec = importlib.util.spec_from_file_location("codex_theme", DESKTOP / "codex-theme.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class CodexThemeTests(unittest.TestCase):
    def test_preserves_settings_when_selecting_theme(self):
        sources = [
            '# model preference\nmodel = "example"\n',
            '[tui]\n# keep this\nnotifications = false\ntheme = "old"\n'
            '[tui.keymap.global]\nsubmit = "enter"\n',
            'tui.theme = "old"\n[features]\nexample = true\n',
            '[tui.keymap.global]\nsubmit = "enter"\n',
            '["tui"]\n"theme" = "old"\nnotifications = false\n',
        ]
        for source in sources:
            with self.subTest(source=source):
                original = tomllib.loads(source)
                result = module.select_theme(source, "blousy-arcane")
                original.setdefault("tui", {})["theme"] = "blousy-arcane"
                self.assertEqual(tomllib.loads(result), original)
                self.assertEqual(module.select_theme(result, "blousy-arcane"), result)
                for line in source.splitlines():
                    if line.startswith("#"):
                        self.assertIn(line, result)

    def test_config_symlink_and_permissions_survive(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            target = home / "user-settings.toml"
            target.write_text('model = "example"\n')
            target.chmod(0o640)
            (home / "config.toml").symlink_to(target)
            module.sync(CATALOG, "arrakis", home)
            self.assertTrue((home / "config.toml").is_symlink())
            self.assertEqual(target.stat().st_mode & 0o777, 0o640)
            self.assertEqual(tomllib.loads(target.read_text())["tui"]["theme"],
                             "blousy-arrakis")

    def test_invalid_config_or_palette_does_not_write(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            config = home / "config.toml"
            config.write_text("[invalid\n")
            with self.assertRaises(ValueError):
                module.sync(CATALOG, "arrakis", home)
            self.assertFalse((home / "themes").exists())
            config.write_text('model = "example"\n')
            catalog = json.loads(CATALOG.read_text())
            catalog["themes"][1]["palette"]["accent"] = "invalid"
            bad_catalog = home / "catalog.json"
            bad_catalog.write_text(json.dumps(catalog))
            with self.assertRaises(ValueError):
                module.sync(bad_catalog, "arrakis", home)
            self.assertFalse((home / "themes").exists())
            self.assertEqual(config.read_text(), 'model = "example"\n')

    def test_desktop_apply_switches_codex_and_generates_every_palette(self):
        with tempfile.TemporaryDirectory() as directory:
            temporary = Path(directory)
            config_home = temporary / "config"
            config_home.mkdir()
            for name in ("desktop", "nvim", "fastfetch", "starship.toml"):
                (config_home / name).symlink_to(ROOT / "config" / name)
            codex_home = temporary / "codex"
            environment = {
                **os.environ,
                "XDG_CONFIG_HOME": str(config_home),
                "XDG_STATE_HOME": str(temporary / "state"),
                "CODEX_HOME": str(codex_home),
                "HYPRLAND_INSTANCE_SIGNATURE": "",
            }
            # Keep reload commands isolated from the real desktop session.
            commands = temporary / "bin"
            commands.mkdir()
            (commands / "makoctl").write_text("#!/bin/sh\nexit 0\n")
            (commands / "makoctl").chmod(0o755)
            environment["PATH"] = f"{commands}:{environment['PATH']}"
            themes = json.loads(CATALOG.read_text())["themes"]
            for theme in themes:
                subprocess.run([str(DESKTOP / "theme"), "apply", theme["id"]],
                               env=environment, check=True, capture_output=True)
                selected = tomllib.loads((codex_home / "config.toml").read_text())
                self.assertEqual(selected["tui"]["theme"], f"blousy-{theme['id']}")
                self.assertEqual((temporary / "state/blousy/theme").read_text().strip(),
                                 theme["id"])
            for theme in themes:
                path = codex_home / "themes" / f"blousy-{theme['id']}.tmTheme"
                document = plistlib.loads(path.read_bytes())
                self.assertEqual(document["settings"][0]["settings"]["background"],
                                 theme["palette"]["backgroundOpaque"])
                self.assertEqual(document["name"], f"Blousy {theme['name']}")


if __name__ == "__main__":
    unittest.main()
