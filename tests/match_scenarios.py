"""Version 1 match scenario validation and expansion."""
from __future__ import annotations

from copy import deepcopy
import json
import math
from pathlib import Path

TEAM_FIELDS = {"money": int, "wood": int, "workers": int}
STATS = {"king_health", "king_damage", "king_attack_speed", "king_range", "worker_health", "worker_speed", "worker_capacity", "worker_gather", "income"}
UNITS = {"melee", "ranged", "tank"}
UNIT_FIELDS = {"money_cost", "max_health", "damage", "move_speed", "attack_range", "attack_cooldown", "detection_range", "body_radius", "structure_damage_multiplier"}
UPGRADES = {"king_health", "king_damage", "king_attack_speed", "king_range", "worker_speed", "worker_capacity", "worker_gather", "income"}
UPGRADE_FIELDS = {"base_cost", "cost_growth", "amount", "maximum_level"}
BALANCE_FIELDS = {"tower_money", "tower_wood", "tower_health", "tower_damage", "tower_range", "tower_cooldown", "tower_rebuild_delay", "build_reach", "ally_money_reserve", "ally_wood_reserve", "aggressive_decision_seconds", "economic_decision_seconds", "commander_health", "commander_strike_windup", "commander_respawn", "base_heal_cooldown"}
INTEGER_FIELDS = TEAM_FIELDS.keys() | {"worker_cost", "money_cost", "base_cost", "maximum_level", "tower_money", "tower_wood", "ally_money_reserve", "ally_wood_reserve"}


def _number(value, path):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value) or not 0 <= value <= 1_000_000:
        raise ValueError(f"{path}: expected finite nonnegative number <= 1000000")
    if path.rsplit(".", 1)[-1] in INTEGER_FIELDS and not isinstance(value, int):
        raise ValueError(f"{path}: expected integer")
    leaf = path.rsplit(".", 1)[-1]
    if leaf not in {"money", "wood", "workers", "money_cost", "worker_cost", "tower_money", "tower_wood", "ally_money_reserve", "ally_wood_reserve", "base_cost"} and value == 0:
        raise ValueError(f"{path}: expected positive value")


def _fields(data, allowed, path):
    if not isinstance(data, dict):
        raise ValueError(f"{path}: expected object")
    for key, value in data.items():
        if key not in allowed:
            raise ValueError(f"{path}.{key}: unknown field")
        _number(value, f"{path}.{key}")


def validate(config):
    if not isinstance(config, dict) or set(config) - {"shared", "teams"}:
        raise ValueError("config: expected shared and/or teams")
    shared = config.get("shared", {})
    if not isinstance(shared, dict) or set(shared) - {"team", "base_stats", "units", "upgrades", "balance", "worker_cost"}:
        raise ValueError("shared: unknown field")
    if "worker_cost" in shared:
        _number(shared["worker_cost"], "shared.worker_cost")
    _fields(shared.get("team", {}), TEAM_FIELDS, "shared.team")
    _fields(shared.get("base_stats", {}), STATS, "shared.base_stats")
    for group, names, fields in (("units", UNITS, UNIT_FIELDS), ("upgrades", UPGRADES, UPGRADE_FIELDS)):
        data = shared.get(group, {})
        if not isinstance(data, dict) or set(data) - names:
            raise ValueError(f"shared.{group}: unknown resource")
        for name, overrides in data.items():
            _fields(overrides, fields, f"shared.{group}.{name}")
    _fields(shared.get("balance", {}), BALANCE_FIELDS, "shared.balance")
    teams = config.get("teams", {})
    if not isinstance(teams, dict) or set(teams) - {"1", "2"}:
        raise ValueError("teams: expected team IDs 1 and/or 2")
    for team_id, values in teams.items():
        if not isinstance(values, dict) or set(values) - (TEAM_FIELDS.keys() | {"base_stats"}):
            raise ValueError(f"teams.{team_id}: unknown field")
        _fields({k: v for k, v in values.items() if k != "base_stats"}, TEAM_FIELDS, f"teams.{team_id}")
        _fields(values.get("base_stats", {}), STATS, f"teams.{team_id}.base_stats")
    for path in (shared.get("team", {}), *teams.values()):
        if path.get("workers", 0) > 10:
            raise ValueError("workers: maximum is 10")


def load(path: Path):
    doc = json.loads(path.read_text())
    if doc.get("version") != 1 or set(doc) - {"version", "scenarios", "sweeps"}:
        raise ValueError("scenario file: expected version 1 with scenarios/sweeps")
    scenarios = doc.get("scenarios", {})
    if not isinstance(scenarios, dict):
        raise ValueError("scenarios: expected object")
    for name, config in scenarios.items():
        validate(config)
    expanded = dict(scenarios)
    for name, sweep in doc.get("sweeps", {}).items():
        if set(sweep) != {"base", "path", "values"} or sweep["base"] not in scenarios:
            raise ValueError(f"sweep {name}: expected base, path, values")
        if not isinstance(sweep["values"], list) or not sweep["values"]:
            raise ValueError(f"sweep {name}: values must be nonempty")
        for value in sweep["values"]:
            config = deepcopy(scenarios[sweep["base"]])
            cursor = config
            parts = sweep["path"].split(".")
            for part in parts[:-1]:
                cursor = cursor.setdefault(part, {})
            cursor[parts[-1]] = value
            validate(config)
            expanded[f"{name}={value}"] = config
    return expanded


def swapped(config):
    result = deepcopy(config)
    teams = result.get("teams", {})
    result["teams"] = {"1": teams.get("2", {}), "2": teams.get("1", {})}
    return result
