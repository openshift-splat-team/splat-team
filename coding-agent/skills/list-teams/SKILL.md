---
name: List Teams
description: List all teams from the team component mapping
---

# List Teams

This skill provides functionality to list all teams from the team component mapping, including rich metadata about each team (components, description, repos, team size, slack channels).

## When to Use This Skill

Use this skill when you need to:

- Display all available team names
- Validate team names before using them in other commands
- Get a complete list of teams with OCPBUGS components
- Count how many teams are in the system
- Find team names for team-based analysis

## Prerequisites

1. **Python 3 Installation**
   - Check if installed: `which python3`
   - Python 3.6 or later is required

2. **Team Component Mapping File**
   - The mapping file should be in the repository
   - Located at: `plugins/teams/team_component_map.json`
   - This file is committed to the repository

## Implementation Steps

### Step 1: Run the list-teams Script

```bash
python3 plugins/teams/skills/list-teams/list_teams.py
```

### Step 2: Process the Output

The script outputs JSON in one of two formats:

**New Format** (after regeneration with updated script):
```json
{
  "total_teams": 29,
  "teams": {
    "API Server": {
      "components": ["kube-apiserver", "openshift-apiserver", "..."],
      "description": "Team responsible for API server components",
      "team_size": 15,
      "repos": ["openshift/origin", "openshift/kubernetes"],
      "slack_channels": ["forum-apiserver"]
    },
    "Authentication": {
      "components": ["oauth-apiserver", "..."],
      "description": "...",
      "team_size": 10,
      "repos": ["..."],
      "slack_channels": ["..."]
    }
  }
}
```

**Old Format** (before regeneration):
```json
{
  "total_teams": 29,
  "teams": [
    "API Server",
    "Authentication",
    "..."
  ]
}
```

### Step 3: Display to User

**Important**: When displaying results to the user via the `/teams:list-teams` command:
- Show only a concise list of team names
- Do NOT display the full team metadata unless the user specifically asks for it
- Keep the output brief and scannable

**For AI Agent Use**:
- Full team metadata is available for answering follow-up questions
- Can use components, repos, slack_channels to provide context
- Can use team_size and description for additional insights

## Examples

### Example 1: List All Teams

```bash
python3 plugins/teams/skills/list-teams/list_teams.py
```

### Example 2: Count Teams

```bash
python3 plugins/teams/skills/list-teams/list_teams.py | jq '.total_teams'
```

## Notes

- Team data is extracted from the committed mapping file
- Team names are case-sensitive
- Teams are returned in alphabetical order by team name
- Very fast execution (< 100ms)
- Typical count: ~29 teams (teams with OCPBUGS components only)
- Script automatically detects format (new vs old) and handles both
- Rich metadata includes:
  - **components**: List of OCPBUGS components owned by the team
  - **description**: Team's purpose/responsibility
  - **team_size**: Number of team members (count only, no personal info)
  - **repos**: GitHub repositories the team owns
  - **slack_channels**: Forum-type Slack channels (names only)

## Data Source

The team and component mapping data originates from:
- **Source**: https://gitlab.cee.redhat.com/hybrid-platforms/org
- **Access**: Requires Red Hat VPN connection
- **Privacy**: The full org data is considered somewhat private, so this project extracts only the team and component mapping

**If data looks wrong or missing**:
1. Submit a PR to https://gitlab.cee.redhat.com/hybrid-platforms/org to correct the source data
2. After the PR merges, regenerate the mapping file in this repository:
   ```
   python3 plugins/teams/generate_team_component_map.py
   ```
3. Commit the updated `team_component_map.json` file

## Relationship to list-repos Skill

This skill complements the `list-repos` skill but serves a different purpose:

**list-teams (this skill):**
- Source: Red Hat internal org structure (`gs://resolved-org`)
- Purpose: Team organizational ownership
- Data: Teams → repos they formally own (214 repos)
- Refresh: Manual regeneration with `generate_team_component_map.py`
- Use when: You need to know which team is responsible for a repo

**list-repos:**
- Source: GitHub API + CODEOWNERS parsing
- Purpose: PR approval workflow
- Data: All openshift/* repos → current approvers (500+ repos)
- Refresh: Auto (7-day cache)
- Use when: You need to find PR reviewers or locate code

**Key differences:**
1. **Scope**: This skill has 214 team-owned repos; list-repos has 500+ all repos
2. **Approvers**: This skill shows team ownership; list-repos parses CODEOWNERS
3. **Coverage**: This skill only includes repos teams formally own; list-repos includes all repos (even unmaintained/archived)

**When to use both:**
- **Complete picture**: Team formal ownership + current PR approvers
- **Discrepancy detection**: Find where team ownership ≠ CODEOWNERS
- **Work routing**: Team ownership for bugs, CODEOWNERS for PR reviews

**Example:**
```bash
# Find what team owns a component
/teams:list-teams  # Get team list
/teams:list-components --team "API Server"  # Get team's repos

# Then find who actually reviews PRs
/teams:list-repos --search "kubernetes-apiserver"  # Get CODEOWNERS

# These may differ! Team might delegate PR reviews
```

## See Also

- Related Skill: `plugins/teams/skills/list-components/SKILL.md`
- Related Skill: `plugins/teams/skills/list-repos/SKILL.md` - GitHub CODEOWNERS-based repo approvers
- Related Command: `/teams:list-teams`
- Related Command: `/teams:list-repos`
- Mapping File: `plugins/teams/team_component_map.json`
- Generator Script: `plugins/teams/generate_team_component_map.py`
