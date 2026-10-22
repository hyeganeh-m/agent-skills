#!/usr/bin/env bash
set -euo pipefail

# Lists all skills available in a workspace across major agentic harnesses
# (Antigravity, Claude Code, Gemini CLI, OpenAI Codex, GitHub Copilot, Cursor),
# combining workspace-level skills with global and built-in skills.

usage() {
  cat <<'EOF'
Usage: list-workspace-skills.sh [options] [workspace-dir] [harness]

Lists all skills available in <workspace-dir> (default: current directory)
alongside global and built-in skills for supported agentic harnesses.

Arguments:
  workspace-dir            Target project workspace (defaults to ".").
  harness                  Optional harness name: antigravity (or agy), claude,
                           gemini, codex, copilot, cursor, or all (default: all).
                           Can be passed as a positional argument or via --harness.

Options:
  -a, --harness <name>     Filter by harness (same as positional harness argument).
  --workspace-only         Only show workspace-scoped skills.
  --global-only            Only show global (and built-in) skills.
  --no-builtin             Exclude harness built-in/system skills.
  -d, --details            Include each skill's description from SKILL.md.
  --json                   Output results as JSON.
  -h, --help               Show this help message.

Examples:
  list-workspace-skills.sh
  list-workspace-skills.sh ~/projects/my-app
  list-workspace-skills.sh ~/projects/my-app antigravity
  list-workspace-skills.sh claude
  list-workspace-skills.sh --harness gemini ~/projects/my-app
  list-workspace-skills.sh --no-builtin --details ~/projects/my-app
EOF
}

HARNESS=""
SCOPE_FILTER="all"
INCLUDE_BUILTIN=1
SHOW_DETAILS=0
OUTPUT_JSON=0
POSITIONAL=()

is_known_harness() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    agy|antigravity|claude|claude-code|gemini|gemini-cli|codex|openai-codex|copilot|github-copilot|cursor|all)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

while [ $# -gt 0 ]; do
  case "$1" in
    -a|--harness)
      if [ $# -lt 2 ]; then
        echo "error: --harness requires a value" >&2
        exit 2
      fi
      HARNESS="$2"
      shift
      ;;
    --harness=*)
      HARNESS="${1#*=}"
      ;;
    --workspace-only)
      SCOPE_FILTER="workspace"
      ;;
    --global-only)
      SCOPE_FILTER="global"
      ;;
    --no-builtin)
      INCLUDE_BUILTIN=0
      ;;
    -d|--details)
      SHOW_DETAILS=1
      ;;
    --json)
      OUTPUT_JSON=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      while [ $# -gt 0 ]; do POSITIONAL+=("$1"); shift; done
      break
      ;;
    -*)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      POSITIONAL+=("$1")
      ;;
  esac
  shift
done

if [ ${#POSITIONAL[@]} -gt 2 ]; then
  echo "error: too many positional arguments" >&2
  usage >&2
  exit 2
fi

WS_INPUT="."
if [ ${#POSITIONAL[@]} -eq 1 ]; then
  arg0="${POSITIONAL[0]}"
  if [ -z "$HARNESS" ] && is_known_harness "$arg0" && [ ! -d "$arg0" ]; then
    HARNESS="$arg0"
  else
    WS_INPUT="$arg0"
  fi
elif [ ${#POSITIONAL[@]} -eq 2 ]; then
  arg0="${POSITIONAL[0]}"
  arg1="${POSITIONAL[1]}"
  if [ -z "$HARNESS" ] && is_known_harness "$arg0" && [ ! -d "$arg0" ]; then
    HARNESS="$arg0"
    WS_INPUT="$arg1"
  else
    WS_INPUT="$arg0"
    if [ -z "$HARNESS" ]; then
      HARNESS="$arg1"
    else
      echo "error: harness specified both via --harness and positional argument" >&2
      exit 2
    fi
  fi
fi

HARNESS="${HARNESS:-all}"

if [ ! -d "$WS_INPUT" ]; then
  echo "error: workspace directory does not exist: $WS_INPUT" >&2
  exit 1
fi

WS="$(cd "$WS_INPUT" && pwd -P)"

python3 - "$WS" "$HARNESS" "$SCOPE_FILTER" "$INCLUDE_BUILTIN" "$SHOW_DETAILS" "$OUTPUT_JSON" <<'PYEOF'
import json
import os
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

ws_path = Path(sys.argv[1])
harness_arg = sys.argv[2].strip().lower()
scope_filter = sys.argv[3].strip().lower()
include_builtin = sys.argv[4] == "1"
show_details = sys.argv[5] == "1"
output_json = sys.argv[6] == "1"

home = Path(os.environ.get("HOME", str(Path.home())))

HARNESS_ALIASES = {
    "agy": "antigravity",
    "antigravity": "antigravity",
    "claude": "claude",
    "claude-code": "claude",
    "gemini": "gemini",
    "gemini-cli": "gemini",
    "codex": "codex",
    "openai-codex": "codex",
    "copilot": "copilot",
    "github-copilot": "copilot",
    "cursor": "cursor",
    "all": "all",
}

if harness_arg not in HARNESS_ALIASES:
    sys.stderr.write(
        f"error: unknown harness '{harness_arg}'. Choose from: "
        "antigravity, claude, gemini, codex, copilot, cursor, all\n"
    )
    sys.exit(2)

selected_harness = HARNESS_ALIASES[harness_arg]

# Discovery specifications per harness in priority order: workspace -> global -> builtin
# Each entry is (scope, path, max_depth, exclude_subdirs)
HARNESS_SPECS = {
    "antigravity": {
        "label": "Antigravity",
        "roots": [
            ("workspace", ws_path / ".agents" / "skills", 2, []),
            ("workspace", ws_path / ".agent" / "skills", 2, []),
            ("workspace", ws_path / "_agents" / "skills", 2, []),
            ("workspace", ws_path / "_agent" / "skills", 2, []),
            ("global", home / ".gemini" / "config" / "skills", 2, []),
            ("global", home / ".agents" / "skills", 2, []),
            ("builtin", home / ".gemini" / "antigravity" / "builtin" / "skills", 2, []),
        ],
    },
    "claude": {
        "label": "Claude Code",
        "roots": [
            ("workspace", ws_path / ".claude" / "skills", 2, []),
            ("workspace", ws_path / ".agents" / "skills", 2, []),
            ("global", home / ".claude" / "skills", 2, []),
            ("global", home / ".claude" / "plugins", 5, []),
        ],
    },
    "gemini": {
        "label": "Gemini CLI",
        "roots": [
            ("workspace", ws_path / ".gemini" / "skills", 2, []),
            ("workspace", ws_path / ".agents" / "skills", 2, []),
            ("global", home / ".gemini" / "skills", 2, []),
            ("global", home / ".gemini" / "config" / "skills", 2, []),
            ("global", home / ".agents" / "skills", 2, []),
        ],
    },
    "codex": {
        "label": "OpenAI Codex",
        "roots": [
            ("workspace", ws_path / ".codex" / "skills", 2, []),
            ("workspace", ws_path / ".agents" / "skills", 2, []),
            ("global", home / ".codex" / "skills", 2, [".system"]),
            ("global", home / ".agents" / "skills", 2, []),
            ("builtin", home / ".codex" / "skills" / ".system", 2, []),
        ],
    },
    "copilot": {
        "label": "GitHub Copilot",
        "roots": [
            ("workspace", ws_path / ".github" / "skills", 2, []),
            ("workspace", ws_path / ".agents" / "skills", 2, []),
            ("global", home / ".copilot" / "skills", 2, []),
            ("global", home / ".copilot" / "installed-plugins", 5, []),
            ("global", home / ".agents" / "skills", 2, []),
        ],
    },
    "cursor": {
        "label": "Cursor",
        "roots": [
            ("workspace", ws_path / ".cursor" / "skills", 2, []),
            ("workspace", ws_path / ".agents" / "skills", 2, []),
            ("global", home / ".cursor" / "skills", 2, []),
            ("global", home / ".agents" / "skills", 2, []),
            ("builtin", home / ".cursor" / "skills-cursor", 2, []),
        ],
    },
}


def parse_frontmatter(skill_md: Path) -> Tuple[str, str]:
    """Extracts (name, description) from SKILL.md YAML frontmatter."""
    default_name = skill_md.parent.name
    try:
        text = skill_md.read_text(encoding="utf-8", errors="replace")
    except Exception:
        return default_name, ""

    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return default_name, ""

    fm_lines: List[str] = []
    for line in lines[1:]:
        if line.strip() == "---":
            break
        fm_lines.append(line)

    name = default_name
    desc_parts: List[str] = []
    in_desc_block = False

    for line in fm_lines:
        if in_desc_block:
            if line.startswith(" ") or line.startswith("\t"):
                desc_parts.append(line.strip())
                continue
            else:
                in_desc_block = False

        m_name = re.match(r"^name:\s*(.+)$", line)
        if m_name:
            val = m_name.group(1).strip().strip("'\"")
            if val:
                name = val
            continue

        m_desc = re.match(r"^description:\s*(.*)$", line)
        if m_desc:
            rest = m_desc.group(1).strip()
            if rest in [">", ">-", "|", "|-"]:
                in_desc_block = True
            elif rest:
                desc_parts.append(rest.strip("'\""))

    description = " ".join(desc_parts).strip()
    return name, description


def find_skill_mds(root: Path, max_depth: int, exclude_subdirs: List[str]) -> List[Path]:
    if not root.exists() or not root.is_dir():
        return []

    found: List[Path] = []

    def walk(curr: Path, depth: int):
        if depth > max_depth:
            return
        skill_md = curr / "SKILL.md"
        if depth >= 1 and skill_md.is_file():
            found.append(skill_md)
            return
        try:
            entries = sorted(curr.iterdir(), key=lambda p: p.name)
        except Exception:
            return
        for entry in entries:
            if entry.name in exclude_subdirs:
                continue
            if entry.name.startswith(".") and entry.name not in [".system"]:
                continue
            if entry.is_dir():
                walk(entry, depth + 1)

    walk(root, 0)
    return found


def format_path(p: Path) -> str:
    s = str(p)
    ws_s = str(ws_path)
    home_s = str(home)
    if s == ws_s:
        return "."
    if s.startswith(ws_s + "/"):
        return "<workspace>/" + s[len(ws_s) + 1 :]
    if s.startswith(home_s + "/"):
        return "~/" + s[len(home_s) + 1 :]
    return s


def discover_for_harness(h_key: str) -> List[Dict]:
    spec = HARNESS_SPECS[h_key]
    skills: List[Dict] = []
    seen_real_files = set()
    active_by_name: Dict[str, str] = {}

    for scope, root, max_depth, exclude_subdirs in spec["roots"]:
        if scope == "builtin" and not include_builtin:
            continue
        if scope_filter == "workspace" and scope != "workspace":
            continue
        if scope_filter == "global" and scope == "workspace":
            continue

        for skill_md in find_skill_mds(root, max_depth, exclude_subdirs):
            try:
                real_md = str(skill_md.resolve())
            except Exception:
                real_md = str(skill_md)

            # Avoid duplicate reporting within the same scope when two roots point to the
            # same physical directory (e.g. ~/.gemini/config/skills -> ~/.agents/skills)
            scope_key = (scope, real_md)
            if scope_key in seen_real_files:
                continue
            seen_real_files.add(scope_key)

            skill_dir = skill_md.parent
            name, description = parse_frontmatter(skill_md)
            is_symlink = skill_dir.is_symlink() or root.is_symlink()
            resolved_dir = skill_dir.resolve() if is_symlink else None

            overridden_by: Optional[str] = None
            if name in active_by_name:
                overridden_by = active_by_name[name]
            else:
                active_by_name[name] = scope

            skills.append(
                {
                    "name": name,
                    "scope": scope,
                    "location": format_path(skill_dir),
                    "real_location": format_path(resolved_dir) if resolved_dir else format_path(skill_dir),
                    "is_symlink": is_symlink,
                    "symlink_target": format_path(resolved_dir) if resolved_dir else None,
                    "status": f"shadowed by {overridden_by}" if overridden_by else "active",
                    "description": description,
                }
            )

    return skills


harness_keys = (
    list(HARNESS_SPECS.keys()) if selected_harness == "all" else [selected_harness]
)

report = {
    "workspace": str(ws_path),
    "selected_harness": selected_harness,
    "harnesses": {},
}

for hk in harness_keys:
    items = discover_for_harness(hk)
    report["harnesses"][hk] = {
        "label": HARNESS_SPECS[hk]["label"],
        "counts": {
            "workspace": sum(1 for x in items if x["scope"] == "workspace"),
            "global": sum(1 for x in items if x["scope"] == "global"),
            "builtin": sum(1 for x in items if x["scope"] == "builtin"),
            "total": len(items),
        },
        "skills": items,
    }

if output_json:
    print(json.dumps(report, indent=2))
    sys.exit(0)

print(f"Workspace: {ws_path}")
print(f"Harness:   {HARNESS_SPECS[selected_harness]['label'] if selected_harness != 'all' else 'All Harnesses'}")
print("=" * 96)

# 1. Summary table across selected harnesses
print(
    f"\n{'Harness':<18} | {'Workspace':>10} | {'Global':>10} | {'Built-in':>10} | {'Total':>8}"
)
print("-" * 68)
for hk in harness_keys:
    h_data = report["harnesses"][hk]
    c = h_data["counts"]
    print(
        f"{h_data['label']:<18} | {c['workspace']:>10} | {c['global']:>10} | {c['builtin']:>10} | {c['total']:>8}"
    )

# 2. Skills listed by name per harness (or unified when viewing all harnesses)
if len(harness_keys) == 1:
    hk = harness_keys[0]
    h_data = report["harnesses"][hk]
    items = h_data["skills"]
    for scope_key, scope_title in [
        ("workspace", "Workspace Skills"),
        ("global", "Global Skills"),
        ("builtin", "Built-in Skills"),
    ]:
        if scope_key == "builtin" and not include_builtin:
            continue
        if scope_filter == "workspace" and scope_key != "workspace":
            continue
        if scope_filter == "global" and scope_key == "workspace":
            continue

        scoped_items = [x for x in items if x["scope"] == scope_key]
        print(f"\n### {scope_title} ({len(scoped_items)})")
        if not scoped_items:
            print("  (none)")
            continue
        print(f"  {'Skill Name':<38} | {'Status':<22} | Location")
        print("  " + "-" * 98)
        for item in scoped_items:
            loc = item["location"]
            if item["is_symlink"] and item["symlink_target"] and item["symlink_target"] != loc:
                loc = f"{loc} -> {item['symlink_target']}"
            print(f"  {item['name']:<38} | {item['status']:<22} | {loc}")
            if show_details and item["description"]:
                desc = item["description"]
                if len(desc) > 90:
                    desc = desc[:87] + "..."
                print(f"      desc: {desc}")
else:
    # Group skills by scope across all harnesses so every skill name is listed cleanly
    for scope_key, scope_title in [
        ("workspace", "Workspace Skills (Project-Specific)"),
        ("global", "Global Skills (Shared / User-Level)"),
        ("builtin", "Built-in Skills (Harness System Defaults)"),
    ]:
        if scope_key == "builtin" and not include_builtin:
            continue
        if scope_filter == "workspace" and scope_key != "workspace":
            continue
        if scope_filter == "global" and scope_key == "workspace":
            continue

        # Aggregate unique (name, real_location) entries across harnesses
        grouped: Dict[Tuple[str, str], Dict] = {}
        for hk in harness_keys:
            h_label = report["harnesses"][hk]["label"]
            for item in report["harnesses"][hk]["skills"]:
                if item["scope"] != scope_key:
                    continue
                key = (item["name"], item["real_location"])
                if key not in grouped:
                    grouped[key] = {
                        "name": item["name"],
                        "real_location": item["real_location"],
                        "harnesses": [h_label],
                        "status": item["status"],
                        "description": item["description"],
                    }
                else:
                    if h_label not in grouped[key]["harnesses"]:
                        grouped[key]["harnesses"].append(h_label)

        entries = sorted(grouped.values(), key=lambda x: (x["name"], x["real_location"]))
        print(f"\n### {scope_title} ({len(entries)})")
        if not entries:
            print("  (none)")
            continue
        print(f"  {'Skill Name':<38} | {'Available In':<42} | Source Location")
        print("  " + "-" * 115)
        for entry in entries:
            if len(entry["harnesses"]) == len(harness_keys):
                harnesses_str = "All (6 harnesses)"
            else:
                harnesses_str = ", ".join(entry["harnesses"])
            loc_str = entry["real_location"]
            if entry["status"] != "active":
                loc_str = f"{loc_str} ({entry['status']})"
            print(f"  {entry['name']:<38} | {harnesses_str:<42} | {loc_str}")
            if show_details and entry["description"]:
                desc = entry["description"]
                if len(desc) > 96:
                    desc = desc[:93] + "..."
                print(f"      desc: {desc}")
PYEOF
