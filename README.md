# Agent Skills

> The structure and organization of this repository are inspired by [mattpocock/skills](https://github.com/mattpocock/skills).

Modular, high-leverage AI agent skills designed for real engineering workflows. Compatible with **Antigravity**, **Claude Code**, **Gemini CLI**, **OpenAI Codex**, **GitHub Copilot**, **Cursor**, and any harness supporting the [Agent Skills](https://github.com/agentskills/agentskills) standard.

---

## Skill Catalog

### Ping Identity (`skills/ping-identity/`)

| Skill | Description | Docs |
| :--- | :--- | :--- |
| [`ping-docs`](./skills/ping-identity/ping-docs/SKILL.md) | Query and fetch official Ping Identity, ForgeRock, PingAM, PingDS, PingIDM, and Auth Node documentation directly from online Markdown endpoints (`docs.pingidentity.com/llms.txt`). | [Guide](./docs/ping-identity/ping-docs.md) |

---

## Repository CLI Tools (`scripts/`)

| Script | Purpose |
| :--- | :--- |
| [`./scripts/list-skills.sh`](./scripts/list-skills.sh) | Lists all skills available inside this repository by name, category bucket, and path. |
| [`./scripts/link-skills.sh`](./scripts/link-skills.sh) | Symlinks all or selected skills globally into `~/.agents/skills` and `~/.claude/skills`. |
| [`./scripts/link-skills-workspace.sh`](./scripts/link-skills-workspace.sh) | Symlinks all or selected skills into a specific project workspace (`<workspace>/.agents/skills`). |
| [`./scripts/list-workspace-skills.sh`](./scripts/list-workspace-skills.sh) | Inspects a project workspace and lists all available skills (workspace, global, and built-in) across agentic harnesses. |
| [`./scripts/test-skills.sh`](./scripts/test-skills.sh) | Runs syntax checks, `SKILL.md` frontmatter validation, secret/path leak audits, and functional tests. |

---

## Installation & Setup

### Option 1: Global Symlink Installation (`link-skills.sh`)

Clone the repository and run [`link-skills.sh`](./scripts/link-skills.sh). This creates symlinks into `~/.agents/skills` and `~/.claude/skills`, so a `git pull` keeps all installed skills up to date automatically. You can link all skills, a specific category, or individual skills:

```bash
git clone https://github.com/hyeganeh-m/agent-skills.git
cd agent-skills

# Link all skills globally
./scripts/link-skills.sh

# Link a single skill by name
./scripts/link-skills.sh ping-docs

# Link all skills inside a category
./scripts/link-skills.sh ping-identity

# Preview changes without modifying the filesystem
./scripts/link-skills.sh --dry-run

# Replace an existing real (non-symlink) directory with the same skill name
./scripts/link-skills.sh --force ping-docs
```

| Option | Effect |
| :--- | :--- |
| `--force` | Replace an existing real folder with the same skill name. Without it, existing real folders are skipped and left untouched. |
| `--dry-run` | Show what would happen without changing anything. |
| `-h, --help` | Show usage and examples. |

---

### Option 2: Workspace Symlink Installation (`link-skills-workspace.sh`)

Use [`link-skills-workspace.sh`](./scripts/link-skills-workspace.sh) to link skills into a specific project folder (`<workspace>/.agents/skills`) instead of your home directory. You can pass one or more skill names or category folders, or omit them to link every skill in this repository:

```bash
# Link all skills into a workspace
./scripts/link-skills-workspace.sh ~/projects/my-app

# Link a single skill into a workspace
./scripts/link-skills-workspace.sh ~/projects/my-app ping-docs

# Link every skill in a category into a workspace
./scripts/link-skills-workspace.sh ~/projects/my-app ping-identity

# Preview only, and also link into <workspace>/.claude/skills
./scripts/link-skills-workspace.sh --dry-run --claude ~/projects/my-app ping-identity
```

| Option | Effect |
| :--- | :--- |
| `--claude` | Also link into `<workspace>/.claude/skills` (Claude Code). |
| `--force` | Replace an existing real folder with the same skill name. Without it, such folders are skipped and left untouched. |
| `--dry-run` | Show what would happen without changing anything. |
| `-h, --help` | Show usage and examples. |

> If the target workspace is a git repository, the symlinks point to absolute paths on your machine. Add them to that repository's `.gitignore` if you do not want to commit them.

---

### Option 3: Static Copy Into an Agent Directory

If you prefer static files without symlinks, copy the desired skill folder directly into your harness:

```bash
# For Codex / Antigravity / Gemini CLI / Copilot / Cursor (.agents/skills standard):
cp -r skills/ping-identity/ping-docs ~/.agents/skills/

# For Claude Code:
cp -r skills/ping-identity/ping-docs ~/.claude/skills/
```

---

## Listing & Inspecting Skills

### 1. List Skills in This Repository (`list-skills.sh`)

```bash
./scripts/list-skills.sh
```

### 2. Inspect Workspace, Global & Built-in Skills Across Harnesses (`list-workspace-skills.sh`)

Use [`list-workspace-skills.sh`](./scripts/list-workspace-skills.sh) to inspect all skills available in a project workspace across supported agentic harnesses (**Antigravity**, **Claude Code**, **Gemini CLI**, **OpenAI Codex**, **GitHub Copilot**, and **Cursor**). It reports summary statistics per harness and lists every skill by name across **Workspace**, **Global**, and **Built-in** scopes:

```bash
# Inspect current working directory across all harnesses
./scripts/list-workspace-skills.sh

# Inspect a specific project workspace across all harnesses
./scripts/list-workspace-skills.sh ~/projects/my-app

# Inspect a single harness (pass harness name positionally or via --harness)
./scripts/list-workspace-skills.sh ~/projects/my-app antigravity
./scripts/list-workspace-skills.sh claude
./scripts/list-workspace-skills.sh --harness codex ~/projects/my-app

# Only show workspace skills, or only show global skills
./scripts/list-workspace-skills.sh --workspace-only ~/projects/my-app
./scripts/list-workspace-skills.sh --global-only ~/projects/my-app

# Exclude built-in harness system skills and include skill descriptions
./scripts/list-workspace-skills.sh --no-builtin --details ~/projects/my-app

# Export the full report as JSON
./scripts/list-workspace-skills.sh --json ~/projects/my-app
```

| Argument / Option | Effect |
| :--- | :--- |
| `[workspace-dir]` | Target project workspace directory (defaults to current directory `.`). |
| `[harness]` / `-a, --harness <name>` | Filter by harness: `antigravity` (or `agy`), `claude`, `gemini`, `codex`, `copilot`, `cursor`, or `all` (default: `all`). |
| `--workspace-only` | Only display workspace-scoped skills. |
| `--global-only` | Only display global (and built-in) skills. |
| `--no-builtin` | Exclude harness built-in/system skills. |
| `-d, --details` | Include each skill's description from `SKILL.md`. |
| `--json` | Output structured JSON report. |
| `-h, --help` | Show usage and examples. |

---

## Verification & Testing

This repository includes an automated testing and sanitization gate:

```bash
./scripts/test-skills.sh
```

The test runner validates:
1. Shell script syntax (`bash -n`).
2. Python script syntax (`python3 -m py_compile`).
3. `SKILL.md` YAML frontmatter conformity (`name`, `description`).
4. **Sanitization Audit**: Scans for hardcoded secrets, machine-specific paths (`/Users/`, `/home/`), and private local domains.
5. Functional test execution of `ping-docs.py`, `link-skills-workspace.sh`, `link-skills.sh`, and `list-workspace-skills.sh`.

---

## Authoring New Skills

To add a new skill to this repository:
1. Choose the appropriate category (e.g. `skills/ping-identity/`).
2. Create the skill directory: `skills/<bucket>/<skill-name>/`.
3. Add `SKILL.md` with standard YAML frontmatter:
   ```yaml
   ---
   name: your-skill-name
   description: Summary of what this skill does and when to invoke it.
   ---
   ```
4. Place any companion scripts inside `skills/<bucket>/<skill-name>/scripts/`. Ensure all scripts are self-contained and use dynamic path resolutions.
5. Add a human documentation page in `docs/<bucket>/<skill-name>.md`.
6. Run `./scripts/test-skills.sh` to ensure all checks pass.
