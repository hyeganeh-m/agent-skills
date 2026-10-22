# AGENTS.md — Repository Guidelines for AI Assistants

This repository contains custom, modular agent skills. Follow these guidelines whenever adding, modifying, or auditing skills in this repository.

---

## 1. Repository Layout

```
skills/
└── ping-identity/     <-- Production-ready Ping Identity platform skills
docs/                  <-- Human-facing documentation mirroring the skills/ tree
scripts/               <-- Maintenance utilities (link, list, test)
```

---

## 2. Inviolable Security & Sanitization Rules

Any pull request, commit, or skill added to this repository MUST strictly satisfy these invariants:

1. **Zero Hardcoded Secrets**:
   - Never commit passwords, tokens, API keys, bearer headers, or TLS private keys.
   - Do not commit fixtures containing dummy passwords that resemble production credentials.
2. **Zero Machine-Specific Local Paths**:
   - Never reference `/Users/<username>/` or `/home/<username>/`.
   - All file and cache resolutions must use dynamic APIs:
     - Python: `Path.home()`, `Path(__file__).resolve()`, or `os.environ.get(...)`.
     - Shell: `$(cd "$(dirname "$0")/.." && pwd)` or `$HOME`.
3. **Zero Internal Endpoints**:
   - Do not commit internal local development hostnames (`*.local`, `*.internal`, `localhost` endpoints with credentials).
   - Only use official, public documentation endpoints.
4. **Self-Contained Packaging**:
   - Helper scripts and templates required by a skill must live inside that skill's subdirectory (e.g. `skills/<bucket>/<skill-name>/scripts/`).
   - Skills must not depend on external directories outside their package.

---

## 3. Skill Authoring Standards

Every skill requires:
1. **`SKILL.md`**:
   - Valid YAML frontmatter:
     ```yaml
     ---
     name: <kebab-case-name>
     description: >-
       Clear, concise summary of what this skill does and when an agent should invoke it.
     ---
     ```
   - Clear markdown sections: purpose, quick reference, execution commands, and procedures.
2. **Companion Documentation (`docs/<bucket>/<skill-name>.md`)**:
   - **What it does**
   - **When to reach for it**
   - **Common commands & examples**
   - **It's working if...**
3. **Catalog Update**:
   - Update `README.md` table of skills and the bucket's `README.md`.

---

## 4. Quality Gate & Testing

Before committing any change, run:
```bash
./scripts/test-skills.sh
```
All checks (shell syntax, python syntax, frontmatter validation, sanitization audit, and functional tests) must pass with 0 errors.
