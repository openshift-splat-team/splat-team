# Jira Integration for Superman Member

## Quick Reference

When processing epics that reference Jira issues, automatically fetch and integrate Jira context.

## PO Triage Hat - Jira Integration

When wearing the `po_backlog` hat and processing `po:triage` issues:

### 1. Detect Jira References

Check epic issue body and title for Jira issue keys matching pattern: `[A-Z]+-\d+`

Common Red Hat Jira projects:
- `OCPBUGS-*` - OpenShift bugs
- `CNTRLPLANE-*` - Control Plane issues  
- `STOR-*` - Storage issues
- `MULTIARCH-*` - Multi-architecture issues

### 2. Fetch Jira Context

If a Jira key is found, use the fetch-jira-issue skill:

```bash
# Set path to skill
JIRA_SKILL_PATH="team/coding-agent/skills/fetch-jira-issue/fetch_jira_issue.py"

# Extract Jira key from issue body (example: OCPBUGS-12345)
jira_key=$(echo "$issue_body" | grep -oP '[A-Z]+-\d+' | head -1)

# Fetch JSON data
jira_json=$(python3 "$JIRA_SKILL_PATH" "$jira_key" --format json 2>&1)

# Check if fetch succeeded
if [ $? -eq 0 ]; then
  # Parse key fields
  jira_summary=$(echo "$jira_json" | jq -r '.summary')
  jira_status=$(echo "$jira_json" | jq -r '.status')
  jira_priority=$(echo "$jira_json" | jq -r '.priority')
  jira_assignee=$(echo "$jira_json" | jq -r '.assignee.display_name // "Unassigned"')
  jira_components=$(echo "$jira_json" | jq -r '.components | join(", ")')
  jira_url=$(echo "$jira_json" | jq -r '.url')
else
  echo "Warning: Could not fetch Jira issue $jira_key (may need credentials)"
fi
```

### 3. Enrich Epic Issue

Update the epic issue body to include Jira context using `gh issue edit`:

```bash
# Build enriched body
enriched_body="## Jira Reference

**Jira Issue**: [$jira_key]($jira_url)  
**Status**: $jira_status  
**Priority**: $jira_priority  
**Components**: $jira_components  
**Assignee**: $jira_assignee

### Jira Summary

$jira_summary

---

$original_epic_body
"

# Update issue
gh issue edit $issue_number --repo "$TEAM_REPO" --body "$enriched_body"
```

### 4. Include in Triage Comment

Reference Jira context in your triage comment:

```markdown
### 📝 po — 2026-04-16T12:00:00Z

**Triage request**

New epic in triage based on Jira issue **OCPBUGS-12345**:

**Jira Summary**: OVN IPSec creates duplicate OpenSSL attribute  
**Priority**: Critical  
**Component**: Networking / cluster-network-operator  
**Current Status**: Modified (PR in progress)  
**Assignee**: Jane Developer

**Context from Jira**: This issue is already being actively worked on with a PR submitted.

**Recommendation**: Accept to backlog. Coordinate with Jane Developer on current PR progress before starting design work.

Please respond on this issue:
- `Approved` — accept to backlog
- `Rejected: <reason>` — close this epic
```

## Architect Design Hat - Jira Integration

When wearing the `arch_designer` hat and creating design docs:

### Reference Jira in Design Document

Include Jira context in the design doc's problem statement:

```markdown
# Epic Design: [Epic Title]

## Problem Statement

Based on Jira issue [OCPBUGS-12345](https://redhat.atlassian.net/browse/OCPBUGS-12345):

[Problem description from Jira, refined and expanded with architectural context]

**Affected Components**: [from Jira]  
**Priority**: [from Jira]  
**Upstream Work**: [reference any PRs mentioned in Jira]

## Background

[Additional context beyond what Jira provides]
```

## Error Handling

If Jira credentials are not configured or fetch fails:

1. **Don't block epic processing** - proceed without Jira context
2. **Log warning** in poll-log.txt
3. **Add note to epic**:
   ```markdown
   > **Note**: Could not fetch Jira context for automated integration.
   > Manual review recommended: https://redhat.atlassian.net/browse/OCPBUGS-12345
   ```

## Credential Configuration

Jira credentials are configured via systemd environment file:
- Location: `/home/splat/.botminter/workspaces/splat/team/systemd/botminter.env`
- Variables: `JIRA_API_TOKEN`, `JIRA_USERNAME`, `JIRA_URL`
- Loaded automatically by systemd service

To verify credentials are available:
```bash
if [ -z "$JIRA_API_TOKEN" ]; then
  echo "JIRA_API_TOKEN not set - Jira integration disabled"
fi
```

## Benefits of Integration

- **Avoid duplicate work**: Discover existing PRs and assignees from Jira
- **Better prioritization**: Use Jira priority to inform epic ranking
- **Richer context**: Get problem statement, customer impact from Jira
- **Traceability**: Maintain linkage between Red Hat Jira and GitHub epic
- **Informed design**: Access to component ownership and existing analysis

## See Also

- Team knowledge: `team/knowledge/jira-epic-context.md` - Detailed Jira integration guide
- Skill documentation: `team/coding-agent/skills/fetch-jira-issue/SKILL.md`
- Environment setup: `team/systemd/README.md`
