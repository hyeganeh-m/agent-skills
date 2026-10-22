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
./scripts/link-skills.sh
```

### Option 2: Copy Into Specific Agent Directory

If you prefer static files without symlinks, copy the desired skill folder directly into your harness:

```bash
# For Codex / Antigravity / Agent Skills standard:
cp -r skills/ping-identity/ping-docs ~/.agents/skills/

# For Claude Code:
cp -r skills/ping-identity/ping-docs ~/.claude/skills/
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

---

## License

[MIT](./LICENSE) © 2026 Hossein Yeganeh
