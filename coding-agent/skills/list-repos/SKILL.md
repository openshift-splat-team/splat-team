---
name: OpenShift Repository Report
description: Generate cached report of OpenShift repository purpose and approvers
---

# list-repos

This skill provides backend support for the `/teams:list-repos` command and is designed to be consumed by other Claude plugins.

## Purpose

Fetch and cache repository metadata for all repositories in the `github.com/openshift` organization, including:
- Repository name, description, and URL
- Topics/tags
- Approvers from CODEOWNERS file
- Archive status

## Plugin Integration Use Cases

This skill enables other plugins to:

1. **Work Assignment**: Automatically identify repository owners/approvers for:
   - Assigning reviewers to PRs
   - Routing bug reports to the right team
   - Escalating issues to responsible teams

2. **Code Location**: Find where code changes should be made:
   - Locate repos by functionality (e.g., "networking", "storage")
   - Find repos by technology stack (e.g., Go, React)
   - Identify related repositories by topic

3. **Ownership Resolution**: Determine repository ownership for:
   - Architecture decisions (who to consult)
   - Cross-team coordination (who to notify)
   - Documentation updates (who maintains what)

## Cache Strategy

- **Cache file**: `.work/repos-report/repos-cache.json`
- **Cache lifetime**: 7 days
- **Refresh trigger**: Cache older than 7 days or `--refresh` flag
- **Cache format**: JSON with timestamp and repository data

## Data Collection

1. **Repository enumeration**: Use `gh api` to list all repos in openshift org
2. **CODEOWNERS parsing**: For each repo, fetch CODEOWNERS file and extract approvers
3. **Rate limiting**: 1-second sleep between repos, with retry logic for rate limits
4. **Progress tracking**: Show progress during long-running data collection

## CODEOWNERS Parsing

The script extracts approvers by:
1. Fetching the CODEOWNERS file from the default branch
2. Parsing all lines for @mentions (users and teams)
3. Deduplicating approvers across all patterns
4. Marking repos without CODEOWNERS file

## Usage

```bash
# Basic usage
python3 list_repos.py              # Use cache if fresh
python3 list_repos.py --refresh    # Force refresh

# Filtering (works on cached data, no API calls)
python3 list_repos.py --search "networking"
python3 list_repos.py --approver "@team-network"
python3 list_repos.py --topic "go"
python3 list_repos.py --archived "false"

# Combine filters
python3 list_repos.py --topic "go" --approver "@team-cluster-api"
```

## Quick Integration Guide for Plugin Developers

To use this skill from another plugin:

```python
import json
import subprocess

def get_repos(search=None, approver=None, topic=None):
    """Get repository data with optional filtering."""
    cmd = ["python3", "plugins/teams/skills/list-repos/list_repos.py"]
    
    if search:
        cmd.extend(["--search", search])
    if approver:
        cmd.extend(["--approver", approver])
    if topic:
        cmd.extend(["--topic", topic])
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    return json.loads(result.stdout)

# Find repos by keyword
repos = get_repos(search="network")

# Find repos by owner
repos = get_repos(approver="@team-network")

# Find repos by technology
repos = get_repos(topic="go")
```

## Output Format

```json
{
  "cache_date": "2026-04-07T10:30:00Z",
  "cache_age_days": 0,
  "from_cache": false,
  "total_repos": 500,
  "repos": [
    {
      "name": "openshift/console",
      "description": "OpenShift Console UI",
      "url": "https://github.com/openshift/console",
      "topics": ["javascript", "react", "openshift"],
      "archived": false,
      "approvers": ["@team-console", "@user1"],
      "has_codeowners": true
    }
  ]
}
```

## Error Handling

- **Network failures**: Retry with exponential backoff
- **Rate limiting**: Sleep and retry with longer intervals
- **Missing CODEOWNERS**: Mark as `has_codeowners: false`
- **Invalid cache**: Regenerate on any parse errors

## Relationship to list-teams Skill

This skill complements the `list-teams` skill but serves a different purpose:

**list-teams:**
- Source: Red Hat internal org structure
- Purpose: Team organizational ownership
- Data: Teams → repos they formally own (214 repos)
- Use when: You need organizational structure, team responsibilities

**list-repos (this skill):**
- Source: GitHub API + CODEOWNERS parsing
- Purpose: PR approval workflow
- Data: All openshift/* repos → approvers (500+ repos)
- Use when: You need to assign PR reviewers, find code locations

**Why both exist:**
1. **Different scopes**: Teams own 214 repos, but openshift org has 500+ repos
2. **Different data**: Organizational ownership vs operational PR approvers
3. **Different sources**: Internal org structure vs public GitHub data
4. **May diverge**: Team can own a repo but delegate PR reviews

**Example integration:**
```python
# Get repos a team formally owns
team_repos = get_team_repos_from_mapping("API Server")

# Then check who actually approves PRs
for repo in team_repos:
    approvers = find_repo_approvers(repo['name'])
    if set(approvers) != set([f"@{team_name}"]):
        print(f"Divergence: {repo} owned by {team_name} but approved by {approvers}")
```

See `plugins/teams/DATA_SOURCES.md` for detailed comparison and usage guidance.

## Prerequisites

- GitHub CLI (`gh`) installed and authenticated
- Python 3.6+
- Write access to `.work/` directory
