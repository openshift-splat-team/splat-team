#!/usr/bin/env python3
"""
OpenShift Repository Report Script

Generates a comprehensive report of all repositories in github.com/openshift,
including purpose (description) and approvers (from CODEOWNERS).

Caches data locally and refreshes at most once per week.

This script is designed to be consumed by other Claude plugins for:
- Assigning work to the right team/approvers
- Identifying where code changes should be made
- Finding repositories by topic, description, or ownership

Prerequisites:
    GitHub CLI (gh) must be installed and authenticated.

Usage:
    python3 list_repos.py
    python3 list_repos.py --refresh
    python3 list_repos.py --search "networking"
    python3 list_repos.py --approver "@team-network"
    python3 list_repos.py --topic "go"
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime, timedelta

REPO_API_SLEEP = 1  # Sleep between repo API calls to avoid rate limits
RETRY_SLEEP = 30
MAX_RETRIES = 3
CACHE_LIFETIME_DAYS = 7
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
WORK_DIR = os.path.join(os.path.dirname(SCRIPT_DIR), "..", "..", ".work", "repos-report")
CACHE_FILE = os.path.join(WORK_DIR, "repos-cache.json")


def ensure_work_dir():
    """Create work directory if it doesn't exist."""
    os.makedirs(WORK_DIR, exist_ok=True)


def load_cache():
    """Load cache file if it exists and is valid."""
    if not os.path.exists(CACHE_FILE):
        return None

    try:
        with open(CACHE_FILE, 'r') as f:
            cache = json.load(f)

        # Validate cache structure
        if not isinstance(cache, dict) or 'cache_date' not in cache or 'repos' not in cache:
            print("Invalid cache format, will regenerate", file=sys.stderr)
            return None

        return cache
    except (json.JSONDecodeError, IOError) as e:
        print(f"Error reading cache: {e}, will regenerate", file=sys.stderr)
        return None


def save_cache(data):
    """Save data to cache file."""
    ensure_work_dir()
    try:
        with open(CACHE_FILE, 'w') as f:
            json.dump(data, f, indent=2)
    except IOError as e:
        print(f"Warning: Could not save cache: {e}", file=sys.stderr)


def is_cache_fresh(cache, force_refresh=False):
    """Check if cache is less than CACHE_LIFETIME_DAYS old."""
    if force_refresh:
        return False

    if cache is None:
        return False

    try:
        cache_date = datetime.fromisoformat(cache['cache_date'].replace('Z', '+00:00'))
        age = datetime.now().astimezone() - cache_date
        return age.days < CACHE_LIFETIME_DAYS
    except (ValueError, KeyError):
        return False


def gh_api_call(endpoint, params=None, retry_count=0):
    """Make a GitHub API call using gh CLI with retry logic."""
    cmd = ["gh", "api", endpoint]

    if params:
        for key, value in params.items():
            cmd.extend(["-f", f"{key}={value}"])

    for attempt in range(MAX_RETRIES):
        try:
            result = subprocess.run(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                universal_newlines=True,
                timeout=30
            )

            if result.returncode == 0:
                return json.loads(result.stdout)

            stderr = result.stderr.lower()
            if "rate limit" in stderr or "403" in stderr:
                wait = RETRY_SLEEP * (attempt + 1)
                print(f"  Rate limited, waiting {wait}s (attempt {attempt + 1}/{MAX_RETRIES})...", file=sys.stderr)
                time.sleep(wait)
            else:
                print(f"  API error: {result.stderr.strip()}", file=sys.stderr)
                return None

        except subprocess.TimeoutExpired:
            print(f"  Timeout after 30s (attempt {attempt + 1}/{MAX_RETRIES})...", file=sys.stderr)
        except json.JSONDecodeError as e:
            print(f"  JSON decode error: {e}", file=sys.stderr)
            return None

    return None


def fetch_all_repos():
    """Fetch all repositories from the openshift organization."""
    repos = []
    page = 1

    print("Fetching repository list from GitHub...", file=sys.stderr)

    while True:
        print(f"  Fetching page {page}...", file=sys.stderr)
        data = gh_api_call(
            "/orgs/openshift/repos",
            params={"per_page": "100", "page": str(page)}
        )

        if data is None:
            print("Failed to fetch repository list", file=sys.stderr)
            return None

        if not data:
            break

        repos.extend(data)

        if len(data) < 100:
            break

        page += 1
        time.sleep(0.5)  # Small delay between pages

    print(f"Found {len(repos)} repositories", file=sys.stderr)
    return repos


def fetch_codeowners(repo_full_name, default_branch):
    """Fetch CODEOWNERS file for a repository."""
    # Try common locations
    locations = [
        "CODEOWNERS",
        ".github/CODEOWNERS",
        "docs/CODEOWNERS"
    ]

    for location in locations:
        endpoint = f"/repos/{repo_full_name}/contents/{location}"
        params = {"ref": default_branch}

        data = gh_api_call(endpoint, params)

        if data and isinstance(data, dict) and data.get("type") == "file":
            # Content is base64 encoded
            import base64
            try:
                content = base64.b64decode(data.get("content", "")).decode("utf-8")
                return content
            except Exception as e:
                print(f"    Error decoding CODEOWNERS: {e}", file=sys.stderr)
                continue

    return None


def parse_codeowners(content):
    """Parse CODEOWNERS file and extract all approvers."""
    if not content:
        return []

    approvers = set()

    # Match @username and @org/team-name patterns
    pattern = r'@[\w-]+(?:/[\w-]+)?'

    for line in content.split('\n'):
        # Skip comments and empty lines
        line = line.strip()
        if not line or line.startswith('#'):
            continue

        # Find all @mentions in the line
        matches = re.findall(pattern, line)
        approvers.update(matches)

    return sorted(list(approvers))


def process_repositories(repos):
    """Process all repositories and extract metadata."""
    processed = []
    total = len(repos)

    print(f"\nProcessing {total} repositories...", file=sys.stderr)

    for i, repo in enumerate(repos, 1):
        name = repo.get("full_name", "")
        print(f"  [{i}/{total}] {name}...", file=sys.stderr)

        # Extract basic metadata
        repo_data = {
            "name": name,
            "description": repo.get("description", "") or "",
            "url": repo.get("html_url", ""),
            "topics": repo.get("topics", []),
            "archived": repo.get("archived", False),
            "approvers": [],
            "has_codeowners": False
        }

        # Fetch and parse CODEOWNERS
        default_branch = repo.get("default_branch", "main")
        codeowners_content = fetch_codeowners(name, default_branch)

        if codeowners_content:
            repo_data["has_codeowners"] = True
            repo_data["approvers"] = parse_codeowners(codeowners_content)
            print(f"    Found {len(repo_data['approvers'])} approvers", file=sys.stderr)
        else:
            print(f"    No CODEOWNERS file found", file=sys.stderr)

        processed.append(repo_data)

        # Rate limiting
        if i < total:
            time.sleep(REPO_API_SLEEP)

    return processed


def generate_report(force_refresh=False):
    """Generate repository report, using cache if available."""
    # Check cache first
    cache = load_cache()

    if is_cache_fresh(cache, force_refresh):
        print("Using cached data", file=sys.stderr)
        cache_date = datetime.fromisoformat(cache['cache_date'].replace('Z', '+00:00'))
        age = (datetime.now().astimezone() - cache_date).days

        return {
            "cache_date": cache['cache_date'],
            "cache_age_days": age,
            "from_cache": True,
            "total_repos": len(cache['repos']),
            "repos": cache['repos']
        }

    # Fetch fresh data
    print("Fetching fresh data from GitHub API...", file=sys.stderr)
    repos = fetch_all_repos()

    if repos is None:
        sys.exit(1)

    processed_repos = process_repositories(repos)

    # Prepare cache data
    cache_date = datetime.now().astimezone().isoformat()
    cache_data = {
        "cache_date": cache_date,
        "repos": processed_repos
    }

    # Save to cache
    save_cache(cache_data)

    print(f"\nReport generated successfully", file=sys.stderr)
    print(f"Cache saved to: {CACHE_FILE}", file=sys.stderr)

    return {
        "cache_date": cache_date,
        "cache_age_days": 0,
        "from_cache": False,
        "total_repos": len(processed_repos),
        "repos": processed_repos
    }


def filter_repos(repos, search=None, approver=None, topic=None, archived=None):
    """Filter repositories based on search criteria."""
    filtered = repos

    if search:
        search_lower = search.lower()
        filtered = [
            r for r in filtered
            if search_lower in r['name'].lower()
            or search_lower in r['description'].lower()
        ]

    if approver:
        filtered = [
            r for r in filtered
            if approver in r['approvers']
        ]

    if topic:
        topic_lower = topic.lower()
        filtered = [
            r for r in filtered
            if any(topic_lower == t.lower() for t in r['topics'])
        ]

    if archived is not None:
        filtered = [
            r for r in filtered
            if r['archived'] == archived
        ]

    return filtered


def main():
    parser = argparse.ArgumentParser(
        description="Generate OpenShift repository report with caching and filtering"
    )
    parser.add_argument(
        "--refresh",
        action="store_true",
        help="Force refresh of cache even if it's fresh"
    )
    parser.add_argument(
        "--search",
        help="Filter by name or description (case-insensitive substring match)"
    )
    parser.add_argument(
        "--approver",
        help="Filter by approver (exact match, e.g., '@team-network' or '@username')"
    )
    parser.add_argument(
        "--topic",
        help="Filter by topic (exact match, case-insensitive)"
    )
    parser.add_argument(
        "--archived",
        choices=["true", "false"],
        help="Filter by archived status"
    )

    args = parser.parse_args()

    # Generate report
    report = generate_report(force_refresh=args.refresh)

    # Apply filters if any
    if args.search or args.approver or args.topic or args.archived:
        archived_filter = None
        if args.archived == "true":
            archived_filter = True
        elif args.archived == "false":
            archived_filter = False

        filtered_repos = filter_repos(
            report['repos'],
            search=args.search,
            approver=args.approver,
            topic=args.topic,
            archived=archived_filter
        )

        report['repos'] = filtered_repos
        report['total_repos'] = len(filtered_repos)
        report['filtered'] = True
        report['filters'] = {
            'search': args.search,
            'approver': args.approver,
            'topic': args.topic,
            'archived': args.archived
        }
    else:
        report['filtered'] = False

    # Output JSON to stdout
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
