# `ping-docs`

Query and fetch official Ping Identity, ForgeRock, PingAM, PingDS, PingIDM, and Auth Node documentation directly from online Markdown endpoints (`docs.pingidentity.com/llms.txt`).

---

## 1. What it does

`ping-docs` enables AI agents and engineers to find, query, and retrieve authoritative Ping Identity product documentation without guessing REST schemas, reverse engineering WAR/JAR archives, or dealing with heavy web browser rendering.

It leverages Ping's machine-readable `llms.txt` docset indexes and the official 1:1 Markdown alternate invariant: every HTML documentation page on `docs.pingidentity.com` can be fetched cleanly in Markdown by swapping `.html` with `.md`.

---

## 2. When to reach for it

Reach for `ping-docs` whenever you need to:
- Configure PingAM (OpenAM), PingDS (OpenDJ), PingIDM (OpenIDM), PingGateway, or Authentication Nodes.
- Verify CREST REST API endpoints, schemas, headers (such as `Accept-API-Version`, `If-Match`, `If-None-Match`), and valid property names.
- Discover authentication tree node configurations and outcome triggers.
- Check OAuth2 / OIDC client configurations (grant types, token lifetimes, implied consent, scopes).
- Troubleshoot platform errors with authoritative, version-pinned documentation.

---

## 3. Common commands & examples

The companion CLI script (`ping-docs.py`) provides fast keyword search, version filtering, table-of-contents inspection, and content grepping with local 7-day disk caching.

### Listing available docsets
```bash
python3 scripts/ping-docs.py list-products
```

### Searching a specific product & version
```bash
# Search PingAM 7.5 for OAuth2 consent settings
python3 scripts/ping-docs.py search am "consent" --version 7.5

# Search PingDS 7.5 for setup profiles
python3 scripts/ping-docs.py search ds "setup profile" --version 7.5

# Search Authentication Nodes for DataStoreDecisionNode
python3 scripts/ping-docs.py search nodes "DataStoreDecisionNode" --version 7.5
```

### Inspecting headings / table of contents
```bash
python3 scripts/ping-docs.py get https://docs.pingidentity.com/pingam/7.5/am-oauth2/oauth2-manage-consent.md --toc
```

### Grepping for exact keywords
```bash
python3 scripts/ping-docs.py get https://docs.pingidentity.com/pingam/7.5/am-oauth2/oauth2-manage-consent.md --grep "implied"
```

---

## 4. It's working if...

- `list-products` returns the index of official Ping product docsets.
- `search <product> "<term>"` returns ranked Markdown document URLs with scores and snippets.
- `get <url>` fetches clean Markdown content and caches it locally under `~/.cache/ping-docs/` for instant subsequent access.
- Your AI agent consults official documentation first rather than hallucinating unsupported configuration options.
