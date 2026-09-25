#!/usr/bin/env python3
"""Dependency/config checks without Godot; this is not an engine type checker."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
errors = []


def check(condition, message):
    if not condition:
        errors.append(message)


def exact_file(relative):
    current = ROOT
    for part in Path(relative).parts:
        if not current.is_dir() or part not in {p.name for p in current.iterdir()}:
            return False
        current /= part
    return current.is_file()


# Validate first-party game files. Vendored editor addons have their own tests and
# intentionally contain example/destination res:// paths that need not exist yet.
files = sorted(
    p
    for p in ROOT.rglob("*")
    if p.suffix in {".gd", ".tscn", ".tres"}
    and p.relative_to(ROOT).parts[0] != "addons"
)
files.append(ROOT / "project.godot")
references = 0
for path in files:
    text = path.read_text()
    name = str(path.relative_to(ROOT))
    for reference in re.findall(r'"res://([^"\n]+)"', text):
        check(exact_file(reference), f"{name}: missing/case-mismatched {reference}")
        references += 1
    if path.suffix not in {".tscn", ".tres"}:
        continue
    external = re.findall(r'^\[ext_resource .*? id="([^"]+)"\]', text, re.M)
    internal = re.findall(r'^\[sub_resource .*? id="([^"]+)"\]', text, re.M)
    check(len(external) == len(set(external)), f"{name}: duplicate external IDs")
    for reference in re.findall(r'ExtResource\("([^"]+)"\)', text):
        check(reference in external, f"{name}: missing ExtResource {reference}")
    for reference in re.findall(r'SubResource\("([^"]+)"\)', text):
        check(reference in internal, f"{name}: missing SubResource {reference}")
    count = re.search(r'load_steps=(\d+)', text)
    if count:
        check(int(count[1]) == 1 + len(external) + len(internal), f"{name}: wrong load_steps")
    if path.suffix == ".tscn":
        nodes = re.findall(r'^\[node name="([^"]+)"([^\n]*)\]', text, re.M)
        check(bool(nodes), f"{name}: no root node")
        known = {"."}
        for node, attrs in nodes[1:]:
            parent = re.search(r'parent="([^"]+)"', attrs)
            check(parent is not None, f"{name}: extra root {node}")
            if parent:
                check(parent[1] in known, f"{name}: absent parent {parent[1]}")
                known.add(node if parent[1] == "." else parent[1] + "/" + node)
        script_id = re.search(r'^script = ExtResource\("([^"]+)"\)', text, re.M)
        if script_id:
            script = re.search(r'\[ext_resource type="Script" path="res://([^"]+)" id="' + script_id[1] + r'"\]', text)
            if script and exact_file(script[1]):
                for node_path in re.findall(r'\$([A-Za-z_][A-Za-z_0-9/]*)', (ROOT / script[1]).read_text()):
                    check(node_path in known, f"{name}: script references absent ${node_path}")

config = (ROOT / "project.godot").read_text()
input_section = re.search(r"^\[input\]\s*$([\s\S]*?)(?=^\[|\Z)", config, re.M)
actions = set(re.findall(r"^([A-Za-z_]\w*)=\{", input_section[1], re.M)) if input_section else set()
used_actions = set()
for path in ROOT.glob("scripts/**/*.gd"):
    text = path.read_text()
    used_actions.update(re.findall(r'(?:is_action_pressed|is_action_just_pressed)\("([^"]+)"', text))
    for arguments in re.findall(r'Input\.get_vector\(([^)]+)\)', text):
        used_actions.update(re.findall(r'"([^"]+)"', arguments))
check(used_actions <= actions, f"Undefined input actions: {used_actions - actions}")
check('run/main_scene="res://scenes/main/main.tscn"' in config, "Main scene not configured")
check('process_mode = 3' in (ROOT / "scenes/ui/hud.tscn").read_text(), "HUD must process while paused")

classes = {}
for path in ROOT.glob("scripts/**/*.gd"):
    for class_name in re.findall(r'^class_name (\w+)', path.read_text(), re.M):
        check(class_name not in classes, f"Duplicate class {class_name}")
        classes[class_name] = path
for path in ROOT.glob("resources/**/*.tres"):
    text = path.read_text()
    declared = re.search(r'script_class="([^"]+)"', text)
    check(declared is not None and declared[1] in classes, f"{path.name}: unknown resource class")
    if "upgrades" in path.parts:
        stat = re.search(r'^stat = &"([^"]+)"', text, re.M)
        check(stat is not None and f'&"{stat[1]}":' in (ROOT / "scripts/core/team.gd").read_text(), f"{path.name}: unknown stat")

if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
print(f"PASS: {len(files)} Godot files, {references} resource paths, scene IDs/node paths, {len(used_actions)} inputs, and upgrade stat keys.")
print("Engine parsing, runtime behavior and visual layout still require Godot.")
