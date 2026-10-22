# Agent Skills

Modular, high-leverage AI agent skills designed for real engineering workflows. Compatible with **Antigravity**, **Claude Code**, **Codex**, and any harness supporting the [Agent Skills](https://github.com/agentskills/agentskills) standard.

---

## Skill Catalog

### Ping Identity (`skills/ping-identity/`)

| Skill | Description | Docs |
| :--- | :--- | :--- |
| [`ping-docs`](./skills/ping-identity/ping-docs/SKILL.md) | Query and fetch official Ping Identity, ForgeRock, PingAM, PingDS, PingIDM, and Auth Node documentation directly from online Markdown endpoints (`docs.pingidentity.com/llms.txt`). | [Guide](./docs/ping-identity/ping-docs.md) |

---

## Installation & Setup

### Option 1: Automatic Symlink (Recommended)

Clone the repository and run the linker script. This creates symlinks into `~/.agents/skills` and `~/.claude/skills`, meaning a simple `git pull` keeps all installed skills up to date automatically:

```bash
git clone https://github.com/hyeganeh-m/agent-skills.git
cd agent-skills

# All skills
./scripts/link-skills.sh

# One skill, or every skill in a category
./scripts/link-skills.sh ping-docs
./scripts/link-skills.sh ping-identity

# Preview only
./scripts/link-skills.sh --dry-run
```

It accepts the same `--force` and `--dry-run` options as the workspace script below. An existing real folder with the same skill name is skipped, not deleted, unless you pass `--force`.

### Option 2: Symlink Into a Specific Workspace

Use `link-skills-workspace.sh` to link skills into one project folder (`<workspace>/.agents/skills`) instead of your home directory. You can choose which skills to link by skill name or by category. With no selection, every skill is linked.

```bash
# All skills
./scripts/link-skills-workspace.sh ~/projects/my-app

# One skill
./scripts/link-skills-workspace.sh ~/projects/my-app ping-docs

# Every skill in a category
./scripts/link-skills-workspace.sh ~/projects/my-app ping-identity

# Preview only, and also link into <workspace>/.claude/skills
./scripts/link-skills-workspace.sh --dry-run --claude ~/projects/my-app ping-identity
```

| Option | Effect |
| :--- | :--- |
| `--claude` | Also link into `<workspace>/.claude/skills` (Claude Code). |
| `--force` | Replace an existing real folder with the same skill name. Without it, such folders are skipped and left untouched. |
| `--dry-run` | Show what would happen without changing anything. |

> If the workspace is a git repository, the symlinks contain absolute paths from your machine. Add them to that repository's `.gitignore` if you don't want to commit them.

### Option 3: Copy Into Specific Agent Directory

If you prefer static files without symlinks, copy the desired skill folder directly into your harness:

```bash
# For Codex / Antigravity / Agent Skills standard:
cp -r skills/ping-identity/ping-docs ~/.agents/skills/

# For Claude Code:
cp -r skills/ping-identity/ping-docs ~/.claude/skills/
```

---

## Inspecting Workspace & Global Skills

Use `./scripts/list-workspace-skills.sh` to inspect all skills available in a project workspace across supported agentic harnesses (**Antigravity**, **Claude Code**, **Gemini CLI**, **OpenAI Codex**, **GitHub Copilot**, and **Cursor**), combining workspace skills with global and built-in skills:

```bash
# Inspect current directory across all harnesses
./scripts/list-workspace-skills.sh

# Inspect a specific project workspace across all harnesses
./scripts/list-workspace-skills.sh ~/projects/my-app

# Inspect a single harness (positional or via --harness: antigravity, claude, gemini, codex, copilot, cursor)
./scripts/list-workspace-skills.sh ~/projects/my-app antigravity
./scripts/list-workspace-skills.sh claude
./scripts/list-workspace-skills.sh --harness gemini ~/projects/my-app

# Exclude built-in harness skills and include skill descriptions
./scripts/list-workspace-skills.sh --no-builtin --details ~/projects/my-app

# Export as JSON
./scripts/list-workspace-skills.sh --json ~/projects/my-app
```

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
5. Functional test execution of companion scripts.

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
