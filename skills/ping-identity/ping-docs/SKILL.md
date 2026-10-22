---
name: ping-docs
description: >-
  Query and fetch official Ping Identity, ForgeRock, PingAM, PingDS, PingIDM, and Auth Node documentation directly from online Markdown endpoints (docs.pingidentity.com/llms.txt) instead of decompiling WAR/JAR binaries. Use whenever configuring Ping services, authoring authentication journeys/nodes, checking CREST REST API schemas, setting OAuth2/OIDC properties, or troubleshooting platform errors.
---

# Ping Identity Documentation Skill

Use this skill to discover and retrieve official Ping Identity documentation in Markdown (`.md`) format directly from Ping's machine-readable docset indexes (`llms.txt`).

> [!IMPORTANT]
> **Documentation First Principle**: Never decompile WAR/JAR files or guess REST schemas by trial-and-error until you have queried Ping's official Markdown documentation. Ping publishes comprehensive, version-specific Markdown endpoints for every component.

---

## 1. Quick Reference: Core Docsets & Shortcuts

Ping Identity structures its documentation around machine-readable `llms.txt` indexes for every product:

| Product | Shortcode / Alias | Docset Index | Primary Versions |
| :--- | :--- | :--- | :--- |
| **PingAM** | `pingam` (or `am`) | `https://docs.pingidentity.com/pingam/llms.txt` | `7.5`, `8.1` |
| **PingDS** | `pingds` (or `ds`) | `https://docs.pingidentity.com/pingds/llms.txt` | `7.5` |
| **PingIDM** | `pingidm` (or `idm`) | `https://docs.pingidentity.com/pingidm/llms.txt` | `7.5` |
| **Auth Nodes** | `auth-node-ref` (or `nodes`) | `https://docs.pingidentity.com/auth-node-ref/llms.txt` | `7.5`, `8.1` |
| **PingGateway** | `pinggateway` (or `gw`) | `https://docs.pingidentity.com/pinggateway/llms.txt` | `2024.x`, `2023.x` |
| **OpenICF** | `openicf` (or `icf`) | `https://docs.pingidentity.com/openicf/llms.txt` | `1.5` |
| **Root Index** | `all` | `https://docs.pingidentity.com/llms.txt` | 35+ products |
| **Developer** | `developer` | `https://developer.pingidentity.com/llms.txt` | SDKs & Tools |

---

## 2. Inviolable Rule: Markdown Alternate Pattern

Every HTML documentation page on `docs.pingidentity.com` has an exact 1:1 Markdown alternate:
- **HTML URL**: `https://docs.pingidentity.com/pingam/7.5/am-oauth2/oauth2-manage-consent.html`
- **Markdown URL**: `https://docs.pingidentity.com/pingam/7.5/am-oauth2/oauth2-manage-consent.md`

Always append `.md` or replace `.html` with `.md`. This returns clean, LLM-optimized Markdown with complete YAML frontmatter (title, description, version, section IDs) and no HTML overhead.

---

## 3. Search & Retrieval Companion CLI

This skill includes a zero-dependency CLI script located in `scripts/ping-docs.py` (relative to this skill folder):

```bash
# Locate the script relative to where the skill is installed:
# e.g. ~/.agents/skills/ping-docs/scripts/ping-docs.py
# or   <repo-root>/skills/ping-identity/ping-docs/scripts/ping-docs.py
```

### Search by Keyword & Version
```bash
# Search PingAM 7.5 for OAuth2 consent settings
python3 scripts/ping-docs.py search am "consent" --version 7.5

# Search Authentication Nodes for DataStoreDecisionNode
python3 scripts/ping-docs.py search nodes "DataStoreDecisionNode" --version 7.5

# Search PingDS 7.5 for setup profiles (idm-repo, am-config, cts)
python3 scripts/ping-docs.py search ds "setup profile" --version 7.5

# Search PingIDM 7.5 for external repository configuration
python3 scripts/ping-docs.py search idm "external repository" --version 7.5

# Search across all core docsets simultaneously
python3 scripts/ping-docs.py search all "refresh token" --version 7.5
```

### Inspect Table of Contents & Headings
```bash
python3 scripts/ping-docs.py get https://docs.pingidentity.com/pingam/7.5/am-oauth2/oauth2-manage-consent.md --toc
```

### Grep Exact Sections / Settings
```bash
python3 scripts/ping-docs.py get https://docs.pingidentity.com/pingam/7.5/am-oauth2/oauth2-manage-consent.md --grep "implied"
```

### Fetch Complete Page
```bash
python3 scripts/ping-docs.py get https://docs.pingidentity.com/pingam/7.5/am-oauth2/oauth2-access_token-endpoint.md
```

---

## 4. Standard Procedure for Ping Tasks

When modifying or debugging Ping platform components, follow this procedure:

1. **Identify the Product & Version**:
   - Determine target component (e.g. PingAM, PingDS, PingIDM) and target version.
2. **Execute a Targeted Search**:
   - Run `ping-docs.py search <product> "<term>" --version <ver>`.
3. **Inspect the Resulting Markdown**:
   - Read the `.md` URL using `ping-docs.py get <url>` or an HTTP fetch tool.
   - Pay special attention to REST payload schemas, required HTTP headers (e.g. `Accept-API-Version`, `If-None-Match`), and valid property names.
4. **Apply Verified Configuration**:
   - Apply the documented parameters directly to your configuration files or scripts.
5. **Verify Against Official Requirements**:
   - Validate that status codes and response headers match documented behavior.
