---
name: Find Repository Owner
description: Helper skill to find repository approvers and ownership information
---

# find-repo-owner

This is a helper skill that wraps `list-repos` to provide convenient repository ownership lookups for other plugins.

## Purpose

Provides simple functions for other plugins to:
- Find approvers for a specific repository
- Find all repositories owned by a team
- Suggest repositories based on functionality keywords
- Determine who to assign work to

## When to Use This Skill

Use this skill when you need to:
- **Assign reviewers**: Find who should review a PR
- **Route issues**: Determine which team owns a component
- **Find code location**: Identify where specific functionality lives
- **Cross-team coordination**: Find all repos a team owns

## Usage from Other Plugins

This skill is meant to be invoked by other plugins, not directly by users.

### Find Approvers for a Repository

```python
import subprocess
import json

def find_repo_approvers(repo_name):
    """Find approvers for a specific repository.
    
    Args:
        repo_name: Repository name (with or without 'openshift/' prefix)
    
    Returns:
        List of approvers or empty list if not found
    """
    # Normalize repo name
    if not repo_name.startswith("openshift/"):
        repo_name = f"openshift/{repo_name}"
    
    # Query for the specific repo
    cmd = [
        "python3",
        "plugins/teams/skills/list-repos/list_repos.py",
        "--search",
        repo_name.split("/")[1]  # Search by repo name only
    ]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    data = json.loads(result.stdout)
    
    # Find exact match
    for repo in data['repos']:
        if repo['name'] == repo_name:
            return repo['approvers']
    
    return []

# Example usage
approvers = find_repo_approvers("openshift/cluster-network-operator")
print(f"Approvers: {', '.join(approvers)}")
```

### Find All Repositories Owned by a Team

```python
def find_team_repos(team_name):
    """Find all repositories owned by a specific team.
    
    Args:
        team_name: Team name (with or without @ prefix)
    
    Returns:
        List of repository objects
    """
    # Normalize team name
    if not team_name.startswith("@"):
        team_name = f"@{team_name}"
    
    cmd = [
        "python3",
        "plugins/teams/skills/list-repos/list_repos.py",
        "--approver",
        team_name
    ]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    data = json.loads(result.stdout)
    
    return data['repos']

# Example usage
repos = find_team_repos("team-network")
for repo in repos:
    print(f"- {repo['name']}: {repo['description']}")
```

### Suggest Repositories by Functionality

```python
def suggest_repos_for_work(keywords):
    """Suggest repositories based on functionality keywords.
    
    Args:
        keywords: String or list of keywords to search for
    
    Returns:
        List of repository objects ranked by relevance
    """
    if isinstance(keywords, list):
        keywords = " ".join(keywords)
    
    cmd = [
        "python3",
        "plugins/teams/skills/list-repos/list_repos.py",
        "--search",
        keywords
    ]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    data = json.loads(result.stdout)
    
    # Rank by keyword presence in description
    repos = data['repos']
    keyword_list = keywords.lower().split()
    
    for repo in repos:
        score = sum(
            1 for kw in keyword_list
            if kw in repo['description'].lower() or kw in repo['name'].lower()
        )
        repo['relevance_score'] = score
    
    return sorted(repos, key=lambda r: r['relevance_score'], reverse=True)

# Example usage
repos = suggest_repos_for_work("network ipv6")
print(f"Top suggestions for network IPv6 work:")
for repo in repos[:5]:
    print(f"- {repo['name']}: {repo['description']}")
    print(f"  Approvers: {', '.join(repo['approvers'])}")
    print(f"  Relevance: {repo['relevance_score']}")
```

### Find Repositories by Technology Stack

```python
def find_repos_by_tech(topic):
    """Find repositories using a specific technology.
    
    Args:
        topic: Topic/technology (e.g., 'go', 'react', 'python')
    
    Returns:
        List of repository objects
    """
    cmd = [
        "python3",
        "plugins/teams/skills/list-repos/list_repos.py",
        "--topic",
        topic
    ]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    data = json.loads(result.stdout)
    
    return data['repos']

# Example usage
go_repos = find_repos_by_tech("go")
print(f"Found {len(go_repos)} Go repositories")
```

## Common Integration Patterns

### Pattern 1: PR Reviewer Assignment

```python
# Given a PR URL or repository name
repo_name = extract_repo_from_pr_url(pr_url)
approvers = find_repo_approvers(repo_name)

if approvers:
    print(f"Suggested reviewers: {', '.join(approvers)}")
else:
    print("Warning: No CODEOWNERS found for this repository")
```

### Pattern 2: Bug Routing

```python
# Given a bug report mentioning a component
component_keywords = extract_keywords_from_bug(bug_description)
suggested_repos = suggest_repos_for_work(component_keywords)

if suggested_repos:
    top_match = suggested_repos[0]
    print(f"Route to: {top_match['name']}")
    print(f"Assign to: {', '.join(top_match['approvers'])}")
```

### Pattern 3: Cross-Team Impact Analysis

```python
# Find all repos that might be affected by a change
affected_areas = ["network", "storage", "api"]
all_affected_repos = []

for area in affected_areas:
    repos = suggest_repos_for_work(area)
    all_affected_repos.extend(repos[:3])  # Top 3 matches per area

# Get unique teams involved
teams = set()
for repo in all_affected_repos:
    teams.update(repo['approvers'])

print(f"Teams to notify: {', '.join(sorted(teams))}")
```

## Cache Behavior

- This skill uses the same cache as `list-repos`
- First call may take 5-10 minutes to populate cache
- Subsequent calls are instant (reading from cache)
- Cache refreshes automatically after 7 days
- Filters are applied to cached data (no API calls)

## Performance Notes

- **First run**: ~5-10 minutes (fetches all repos + CODEOWNERS)
- **Subsequent runs**: <1 second (reads from cache)
- **Filtering**: Instant (applied to cached data)
- **Cache location**: `.work/repos-report/repos-cache.json`

## Error Handling

Always check for empty results:

```python
approvers = find_repo_approvers("openshift/example-repo")
if not approvers:
    # No CODEOWNERS file or repo not found
    print("Warning: Could not find approvers")
```

## Prerequisites

- GitHub CLI (`gh`) installed and authenticated
- Python 3.6+
- Cache must be populated (first run takes ~5-10 minutes)
