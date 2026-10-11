#!/usr/bin/env python3
"""Fail when a project skill mentions a file, script flag, suite or fixture that no longer exists.

Skills in .claude/skills/crownfront-* describe workflows, so they reference
real paths and command-line flags. This catches drift when scripts are renamed
or options are removed, without hard-coding any of those names here.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SKILLS = ROOT / ".claude/skills"
EXTENSIONS = r"py|gd|json|md|yml|mjs|tscn|tres|html"
CHUNK = re.compile(r"[\w./*<>{}$~-]+")
PATH = re.compile(rf"^(?:(?:[\w.-]+/)+[\w.-]*|[\w-]+\.(?:{EXTENSIONS}))$")
IMPLICIT_FLAGS = {"--help"}
SKIP_PREFIXES = ("tests/artifacts", "http", "~/", "/")
PLACEHOLDER = re.compile(r"[<>*{}$]")


def spans(text: str) -> list[str]:
    return re.findall(r"`([^`\n]+)`", text)


def frontmatter(text: str) -> dict[str, str]:
    match = re.match(r"---\n(.*?)\n---\n", text, re.S)
    fields = {}
    for line in (match.group(1).splitlines() if match else []):
        if ":" in line:
            key, value = line.split(":", 1)
            fields[key.strip()] = value.strip()
    return fields


def locate(token: str, skill_dir: Path) -> Path | None:
    token = token.rstrip("/.,:;)")
    bases = (ROOT, skill_dir) if "/" in token else (ROOT, ROOT / "tests", ROOT / "tools", skill_dir, skill_dir / "scripts")
    return next((base / token for base in bases if (base / token).exists()), None)


def paths_in(span: str) -> list[str]:
    chunks = (c.rstrip(".,:;") for c in CHUNK.findall(span))
    return [c for c in chunks if PATH.match(c) and not PLACEHOLDER.search(c) and not c.startswith(SKIP_PREFIXES)]


def check_skill(skill_dir: Path) -> list[str]:
    problems = []
    skill_file = skill_dir / "SKILL.md"
    name = skill_dir.name
    if not skill_file.exists():
        return [f"{name}: missing SKILL.md"]
    text = skill_file.read_text()
    fields = frontmatter(text)
    if fields.get("name") != name:
        problems.append(f"{name}: frontmatter name {fields.get('name')!r} does not match directory")
    if not fields.get("description"):
        problems.append(f"{name}: missing description")
    skill_sources = ""
    for span in spans(text):
        for script in (t for t in paths_in(span) if t.endswith(".py")):
            path = locate(script, skill_dir)
            skill_sources += path.read_text() if path else ""
    for span in spans(text):
        tokens = paths_in(span)
        for token in tokens:
            if not locate(token, skill_dir):
                problems.append(f"{name}: `{token}` does not exist")
        for script in (t for t in tokens if t.endswith(".py")):
            path = locate(script, skill_dir)
            source = path.read_text() if path else ""
            for flag in re.findall(r"(?<![\w-])(--[a-z][\w-]*)", span):
                if flag not in source and flag not in IMPLICIT_FLAGS:
                    problems.append(f"{name}: `{script}` no longer defines {flag}")
            for value in re.findall(r"--suite\s+([a-z_]+)", span):
                if f'"{value}"' not in source and f"'{value}'" not in source:
                    problems.append(f"{name}: `{script}` has no suite {value!r}")
        if span.startswith("--") and not any(t.endswith(".py") for t in tokens):
            # Bare flags such as `--jobs` belong to the scripts this skill uses elsewhere.
            for flag in re.findall(r"(?<![\w-])(--[a-z][\w-]*)", span):
                if flag not in skill_sources and flag not in IMPLICIT_FLAGS:
                    problems.append(f"{name}: no script used by this skill defines {flag}")
        for fixture in re.findall(r"\b\w+_regression\b", span):
            if not (ROOT / "tests" / f"{fixture}.gd").exists():
                problems.append(f"{name}: fixture {fixture} does not exist")
    return problems


def check_all() -> list[str]:
    directories = sorted(p for p in SKILLS.glob("crownfront-*") if p.is_dir()) if SKILLS.exists() else []
    if not directories:
        return ["no skills found under .claude/skills/crownfront-*"]
    return [problem for directory in directories for problem in check_skill(directory)]


def main() -> int:
    problems = check_all()
    for problem in problems:
        print(f"SKILL DRIFT: {problem}")
    if not problems:
        print(f"skills ok ({len(list(SKILLS.glob('crownfront-*')))} checked)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
