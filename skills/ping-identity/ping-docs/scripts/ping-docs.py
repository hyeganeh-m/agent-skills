#!/usr/bin/env python3
"""
Ping Identity Documentation Search & Retrieval Utility

Queries official Ping Identity machine-readable documentation indexes (llms.txt)
and fetches clean Markdown endpoints directly from docs.pingidentity.com.

Usage:
  python3 ping-docs.py search pingam "consent"
  python3 ping-docs.py search pingam "consent" --version 7.5
  python3 ping-docs.py search nodes "DataStoreDecisionNode"
  python3 ping-docs.py search all "token endpoint"
  python3 ping-docs.py get <url> [--toc] [--grep <regex>]
  python3 ping-docs.py list-products
  python3 ping-docs.py list-versions pingam
"""

import argparse
import hashlib
import os
import re
import ssl
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Dict, List, Optional, Tuple

DOCS_BASE = "https://docs.pingidentity.com"
DEVELOPER_BASE = "https://developer.pingidentity.com"
CACHE_DIR = Path(os.environ.get("PING_DOCS_CACHE_DIR", Path.home() / ".cache" / "ping-docs"))
CACHE_TTL_SECONDS = 7 * 24 * 3600  # 7 days

PRODUCT_SHORTCUTS = {
    "am": "pingam",
    "ds": "pingds",
    "idm": "pingidm",
    "nodes": "auth-node-ref",
    "auth-nodes": "auth-node-ref",
    "auth_nodes": "auth-node-ref",
    "gw": "pinggateway",
    "gateway": "pinggateway",
    "icf": "openicf",
    "openicf": "openicf",
    "directory": "pingdirectory",
    "federate": "pingfederate",
    "access": "pingaccess",
    "authorize": "pingauthorize",
}

CORE_DOCSETS = ["pingam", "pingds", "pingidm", "auth-node-ref"]


def create_ssl_context() -> ssl.SSLContext:
    try:
        import certifi
        ctx = ssl.create_default_context(cafile=certifi.where())
    except Exception:
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
    return ctx


def fetch_url(url: str, use_cache: bool = True, force_refresh: bool = False) -> str:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    url_hash = hashlib.sha256(url.encode("utf-8")).hexdigest()[:16]
    safe_name = re.sub(r"[^a-zA-Z0-9_\-\.]", "_", url.split("://")[-1])[:64]
    cache_file = CACHE_DIR / f"{safe_name}_{url_hash}.txt"

    if use_cache and not force_refresh and cache_file.exists():
        if time.time() - cache_file.stat().st_mtime < CACHE_TTL_SECONDS:
            try:
                return cache_file.read_text(encoding="utf-8")
            except Exception:
                pass

    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "AgentSkills-PingDocs/1.0",
            "Accept": "text/markdown, text/plain, */*",
        },
    )
    ctx = create_ssl_context()
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=15) as resp:
            content = resp.read().decode("utf-8", errors="replace")
    except urllib.error.HTTPError as e:
        sys.stderr.write(f"HTTP Error {e.code} fetching {url}\n")
        raise
    except Exception as e:
        sys.stderr.write(f"Network error fetching {url}: {e}\n")
        raise

    try:
        cache_file.write_text(content, encoding="utf-8")
    except Exception:
        pass

    return content


def normalize_product(prod: str) -> str:
    cleaned = prod.strip().lower()
    return PRODUCT_SHORTCUTS.get(cleaned, cleaned)


def parse_llms_txt(content: str) -> Dict[str, List[Dict[str, str]]]:
    sections: Dict[str, List[Dict[str, str]]] = {}
    current_section = "General"
    sections[current_section] = []

    link_re = re.compile(r"^-\s*\[(.*?)\]\((https?://[^\)]+)\)(?::\s*(.*))?$")

    for line in content.splitlines():
        line_str = line.strip()
        if line_str.startswith("#"):
            h_text = line_str.lstrip("#").strip()
            current_section = h_text
            if current_section not in sections:
                sections[current_section] = []
            continue

        m = link_re.match(line_str)
        if m:
            title = m.group(1).strip()
            url = m.group(2).strip()
            desc = m.group(3).strip() if m.group(3) else ""
            sections[current_section].append({
                "title": title,
                "url": url,
                "desc": desc,
            })

    return sections


def list_products(force_refresh: bool = False):
    url = f"{DOCS_BASE}/llms.txt"
    try:
        content = fetch_url(url, force_refresh=force_refresh)
    except Exception:
        sys.exit(1)

    print(f"Available Ping Identity Docsets (from {url}):\n")
    print(f"{'Shortcode / Name':<28} | {'Docset llms.txt URL'}")
    print("-" * 75)

    link_re = re.compile(r"^-\s*\[(.*?)\]\((https?://[^\)]+)\)")
    for line in content.splitlines():
        m = link_re.match(line.strip())
        if m:
            name = m.group(1).strip()
            llms_url = m.group(2).strip()
            shortcode = llms_url.split("/")[-2] if "/llms.txt" in llms_url else name.lower()
            alias_note = ""
            for k, v in PRODUCT_SHORTCUTS.items():
                if v == shortcode and k != shortcode:
                    alias_note = f" (alias: {k})"
                    break
            print(f"{shortcode:<28} | {llms_url}{alias_note}")


def list_versions(product: str, force_refresh: bool = False):
    prod = normalize_product(product)
    url = f"{DOCS_BASE}/{prod}/llms.txt"
    try:
        content = fetch_url(url, force_refresh=force_refresh)
    except Exception:
        sys.exit(1)

    sections = parse_llms_txt(content)
    print(f"Available versions for product '{prod}' (from {url}):\n")
    for sec, entries in sections.items():
        if entries:
            print(f"- {sec} ({len(entries)} documents)")


def extract_search_terms(query: str) -> List[str]:
    """Splits query and extracts individual words, including CamelCase and snake_case tokens."""
    tokens = set()
    cleaned_query = query.strip().lower()
    if cleaned_query:
        tokens.add(cleaned_query)

    for chunk in query.split():
        tokens.add(chunk.lower())
        subwords = re.findall(r"[A-Z]?[a-z]+|[A-Z]+(?=[A-Z][a-z]|\b)|\d+", chunk)
        for w in subwords:
            if len(w) > 1:
                tokens.add(w.lower())
        snake_words = chunk.replace("-", "_").split("_")
        for sw in snake_words:
            if len(sw) > 1:
                tokens.add(sw.lower())

    return [t for t in tokens if t]


def get_target_sections(
    sections: Dict[str, List[Dict[str, str]]], version: Optional[str] = "latest"
) -> Dict[str, List[Dict[str, str]]]:
    if not sections:
        return {}

    ver_clean = (version or "latest").strip().lower()

    if ver_clean == "all":
        return sections

    if ver_clean in ["latest", "default"]:
        # Find the first versioned section with entries (e.g. Pingam 8.1, Pingds 8.1)
        for sec_name, entries in sections.items():
            if not entries:
                continue
            sec_lower = sec_name.lower()
            if "release-notes" in sec_lower or sec_lower in ["general", "overview"]:
                continue
            if re.search(r"\b\d+(\.\d+)?\b", sec_name):
                return {sec_name: entries}
        # Fallback to the first available non-empty section
        for sec_name, entries in sections.items():
            if entries:
                return {sec_name: entries}
        return sections

    # Filter by specific version string (e.g. "7.5", "8.1", "2024")
    filtered = {}
    for sec_name, entries in sections.items():
        if ver_clean in sec_name.lower():
            filtered[sec_name] = entries
    return filtered


def search_single_product(
    prod: str, query_terms: List[str], raw_query: str, version: Optional[str] = "latest", force_refresh: bool = False
) -> List[Tuple[int, str, str, Dict[str, str]]]:
    url = f"{DOCS_BASE}/{prod}/llms.txt"
    try:
        content = fetch_url(url, force_refresh=force_refresh)
    except Exception:
        url = f"{DEVELOPER_BASE}/{prod}/llms.txt"
        try:
            content = fetch_url(url, force_refresh=force_refresh)
        except Exception:
            return []

    sections = parse_llms_txt(content)
    target_sections = get_target_sections(sections, version=version)
    results = []

    for sec_name, entries in target_sections.items():
        for item in entries:
            title = item["title"]
            desc = item["desc"]
            item_url = item["url"]

            search_corpus = f"{title} {desc} {item_url}".lower()

            score = 0
            if raw_query.lower() in title.lower():
                score += 50
            elif raw_query.lower() in desc.lower():
                score += 25

            matched_terms = [t for t in query_terms if t in search_corpus]
            if not matched_terms and score == 0:
                continue

            for t in query_terms:
                if t in title.lower():
                    score += 15
                if t in desc.lower():
                    score += 5
                if t in item_url.lower():
                    score += 3

            score += int((len(matched_terms) / max(len(query_terms), 1)) * 30)
            results.append((score, prod, sec_name, item))

    return results


def search_docs(product: str, query: str, version: Optional[str] = "latest", limit: int = 10, force_refresh: bool = False):
    prod = normalize_product(product)
    query_terms = extract_search_terms(query)

    products_to_search = CORE_DOCSETS if prod == "all" else [prod]

    all_results = []
    for p in products_to_search:
        results = search_single_product(p, query_terms, query, version=version, force_refresh=force_refresh)
        all_results.extend(results)

    all_results.sort(key=lambda x: x[0], reverse=True)

    if not all_results:
        v_info = f" (version: {version})" if version else ""
        print(f"No documents found in '{prod}'{v_info} matching query: '{query}'")
        return

    print(f"Found {len(all_results)} matching documents in '{prod}' (showing top {min(limit, len(all_results))}):\n")
    for idx, (score, p_name, sec, item) in enumerate(all_results[:limit], 1):
        print(f"[{idx}] {item['title']} ({p_name} | {sec})")
        print(f"    URL:  {item['url']}")
        if item['desc']:
            print(f"    Desc: {item['desc']}")
        print()


def get_doc(url: str, force_refresh: bool = False, headings_only: bool = False, grep_pattern: Optional[str] = None):
    if url.endswith(".html"):
        url = url[:-5] + ".md"

    try:
        content = fetch_url(url, force_refresh=force_refresh)
    except Exception:
        sys.exit(1)

    if headings_only:
        print(f"Headings in {url}:\n")
        for line in content.splitlines():
            if line.strip().startswith("#"):
                print(line)
        return

    if grep_pattern:
        pattern = re.compile(grep_pattern, re.IGNORECASE)
        lines = content.splitlines()
        print(f"Matches for '{grep_pattern}' in {url}:\n")
        matching_indices = [i for i, l in enumerate(lines) if pattern.search(l)]
        if not matching_indices:
            print("No matching lines found.")
            return

        printed_lines = set()
        for idx in matching_indices:
            start = max(0, idx - 2)
            end = min(len(lines), idx + 3)
            if start > 0 and start not in printed_lines:
                print("---")
            for i in range(start, end):
                if i not in printed_lines:
                    prefix = "> " if i == idx else "  "
                    print(f"{i+1:5d} {prefix}{lines[i]}")
                    printed_lines.add(i)
        return

    print(content)


def main():
    parser = argparse.ArgumentParser(
        description="Search and fetch official Ping Identity Markdown documentation directly from docs.pingidentity.com."
    )
    subparsers = parser.add_subparsers(dest="subcommand", required=True)

    # list-products
    subparsers.add_parser("list-products", aliases=["products"], help="List all available product docsets")

    # list-versions
    p_ver = subparsers.add_parser("list-versions", aliases=["versions"], help="List versions for a given product")
    p_ver.add_argument("product", help="Product name or alias (e.g. pingam, pingds, pingidm, auth-node-ref)")
    p_ver.add_argument("--refresh", action="store_true", help="Force refresh cache")

    # search
    p_search = subparsers.add_parser("search", help="Search product documentation index")
    p_search.add_argument("product", help="Product name or alias (e.g. am, ds, idm, nodes, all)")
    p_search.add_argument("query", help="Keyword(s) to search for")
    p_search.add_argument("--version", "-v", default="latest", help="Filter by product version (e.g. latest, 7.5, 8.1, all). Default: latest")
    p_search.add_argument("--limit", "-n", type=int, default=10, help="Maximum results to return (default: 10)")
    p_search.add_argument("--refresh", action="store_true", help="Force refresh cache")

    # get
    p_get = subparsers.add_parser("get", help="Fetch and display Markdown doc page")
    p_get.add_argument("url", help="Doc URL (e.g. https://docs.pingidentity.com/pingam/8.1/path/page.md or .html)")
    p_get.add_argument("--toc", action="store_true", help="Display only headings / table of contents")
    p_get.add_argument("--grep", help="Filter and display sections matching a regex pattern")
    p_get.add_argument("--refresh", action="store_true", help="Force refresh cache")

    args = parser.parse_args()

    if args.subcommand in ["list-products", "products"]:
        list_products(force_refresh=getattr(args, "refresh", False))
    elif args.subcommand in ["list-versions", "versions"]:
        list_versions(args.product, force_refresh=args.refresh)
    elif args.subcommand == "search":
        search_docs(args.product, args.query, version=args.version, limit=args.limit, force_refresh=args.refresh)
    elif args.subcommand == "get":
        get_doc(args.url, force_refresh=args.refresh, headings_only=args.toc, grep_pattern=args.grep)


if __name__ == "__main__":
    main()
