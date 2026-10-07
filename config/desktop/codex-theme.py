#!/usr/bin/env python3
"""Generate Codex CLI palettes and select the applied desktop theme."""

import json
import os
from pathlib import Path
import plistlib
import re
import sys
import tempfile
import tomllib


def theme_document(theme):
    palette = theme["palette"]
    colors = {}
    for key in (
        "backgroundOpaque", "foregroundOpaque", "accent", "accentBright",
        "secondary", "contrast", "error", "success",
    ):
        value = palette[key]
        if not re.fullmatch(r"#[0-9a-fA-F]{6}", value):
            raise ValueError(f"Invalid Codex color {key} in {theme['id']}: {value}")
        colors[key] = value
    muted = palette["foregroundMuted"].lstrip("#")
    if not re.fullmatch(r"(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})", muted):
        raise ValueError(f"Invalid muted foreground in {theme['id']}")
    alpha = int(muted[:2], 16) / 255 if len(muted) == 8 else 1
    foreground = muted[-6:]
    background = colors["backgroundOpaque"][1:]
    colors["muted"] = "#" + "".join(
        f"{round(int(foreground[i:i + 2], 16) * alpha + int(background[i:i + 2], 16) * (1 - alpha)):02x}"
        for i in (0, 2, 4)
    )

    def rule(name, scope, color, **settings):
        return {"name": name, "scope": scope,
                "settings": {"foreground": colors[color], **settings}}

    return {
        "name": f"Blousy {theme['name']}",
        "settings": [
            {"settings": {
                "background": colors["backgroundOpaque"],
                "foreground": colors["foregroundOpaque"],
                "caret": colors["accentBright"],
                "selection": colors["secondary"],
                "lineHighlight": colors["contrast"] + "40",
            }},
            rule("Comments", "comment, punctuation.definition.comment", "muted",
                 fontStyle="italic"),
            rule("Keywords", "keyword, storage", "accent", fontStyle="bold"),
            rule("Strings", "string", "success"),
            rule("Numbers and constants", "constant", "accentBright"),
            rule("Functions", "entity.name.function, support.function", "accentBright"),
            rule("Types", "entity.name.type, entity.name.class, support.type, support.class",
                 "accent"),
            rule("Variables", "variable", "foregroundOpaque"),
            # Bash scopes executable names and options as variables. Keep
            # unquoted arguments neutral instead of coloring them like strings.
            rule("Shell arguments", "source.shell string.unquoted", "foregroundOpaque"),
            rule("Shell commands",
                 "source.shell variable.function, source.shell entity.name.function, "
                 "source.shell support.function", "accentBright", fontStyle="bold"),
            rule("Shell options",
                 "source.shell variable.parameter, source.shell constant.other.option",
                 "accent"),
            rule("Shell variables",
                 "source.shell variable.other, source.shell variable.language, "
                 "source.shell punctuation.definition.variable", "accentBright"),
            rule("Tags", "entity.name.tag", "accent"),
            rule("Attributes", "entity.other.attribute-name", "accentBright"),
            rule("Invalid", "invalid", "error"),
            rule("Inserted", "markup.inserted", "success"),
            rule("Deleted", "markup.deleted", "error"),
            rule("Changed", "markup.changed", "accentBright"),
            rule("Headings", "markup.heading", "accent", fontStyle="bold"),
            rule("Bold", "markup.bold", "foregroundOpaque", fontStyle="bold"),
            rule("Italic", "markup.italic", "foregroundOpaque", fontStyle="italic"),
        ],
    }


def select_theme(source, name):
    """Edit only tui.theme, retaining all unrelated config text and comments."""
    parsed = tomllib.loads(source)
    lines = source.splitlines(keepends=True)
    header = re.compile(r'^\s*\[\s*(?:tui|"tui"|\'tui\')\s*\]\s*(?:#.*)?$')
    table = re.compile(r"^\s*\[")
    setting = re.compile(r'^\s*(?:theme|"theme"|\'theme\')\s*=')
    replacement = f'theme = {json.dumps(name)}\n'
    for start, line in enumerate(lines):
        if not header.match(line.rstrip("\r\n")):
            continue
        end = next((i for i in range(start + 1, len(lines)) if table.match(lines[i])),
                   len(lines))
        for i in range(start + 1, end):
            if setting.match(lines[i]):
                lines[i] = replacement
                break
        else:
            lines.insert(start + 1, replacement)
        result = "".join(lines)
        break
    else:
        # A dotted key may define tui without a [tui] section.
        end = next((i for i, line in enumerate(lines) if table.match(line)), len(lines))
        dotted = re.compile(r'^\s*tui\.theme\s*=')
        for i in range(end):
            if dotted.match(lines[i]):
                lines[i] = f'tui.{replacement}'
                result = "".join(lines)
                break
        else:
            if any(re.match(r'^\s*(?:tui|"tui"|\'tui\')\s*[.=]', line)
                   for line in lines[:end]):
                raise ValueError("Use a [tui] section in Codex config.toml before syncing themes")
            result = source.rstrip("\r\n") + f'\n\n[tui]\n{replacement}'
    expected = {**parsed, "tui": {**parsed.get("tui", {}), "theme": name}}
    if tomllib.loads(result) != expected:
        raise ValueError("Codex theme edit would change unrelated settings")
    return result


def atomic_write(path, content):
    # Follow an existing config symlink instead of replacing it.
    path = path.resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = path.stat().st_mode & 0o777 if path.exists() else 0o600
    descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(descriptor, "wb") as output:
            output.write(content)
            os.fchmod(output.fileno(), mode)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def sync(catalog, selected, codex_home):
    themes = json.loads(catalog.read_text())["themes"]
    documents = {}
    for theme in themes:
        theme_id = theme["id"]
        if not re.fullmatch(r"[a-zA-Z0-9_-]+", theme_id) or theme_id in documents:
            raise ValueError(f"Invalid or duplicate theme ID: {theme_id}")
        documents[theme_id] = plistlib.dumps(theme_document(theme))
    if selected not in documents:
        raise ValueError(f"Unknown desktop theme: {selected}")
    config = codex_home / "config.toml"
    source = config.read_text() if config.exists() else ""
    updated = select_theme(source, f"blousy-{selected}")
    # Validate every palette and the config before touching live files.
    for theme_id, document in documents.items():
        atomic_write(codex_home / "themes" / f"blousy-{theme_id}.tmTheme", document)
    if updated != source:
        atomic_write(config, updated.encode())


if __name__ == "__main__":
    try:
        if len(sys.argv) != 3:
            raise ValueError("Usage: codex-theme.py CATALOG THEME")
        sync(Path(sys.argv[1]), sys.argv[2],
             Path(os.environ.get("CODEX_HOME", str(Path.home() / ".codex"))))
    except (OSError, ValueError, KeyError, TypeError) as error:
        sys.exit(f"Could not sync Codex CLI theme: {error}")
