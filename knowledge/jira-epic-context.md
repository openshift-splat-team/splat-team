# Jira Epic Context Integration

## Overview

When creating a new epic from a Jira Feature/Epic/Issue, automatically fetch and incorporate Jira context into the epic's GitHub issue body and design process.

## When to Fetch Jira Context

Fetch Jira context when:
- The epic issue body contains a Jira issue reference (e.g., `OCPBUGS-12345`, `CNTRLPLANE-456`)
- The epic title mentions a Jira issue key
- A human comment on the epic provides a Jira reference during triage

## How to Fetch Jira Context

Use the `fetch-jira-issue` skill available in `team/coding-agent/skills/fetch-jira-issue/`:

```bash
# Fetch Jira issue details in JSON format
python3 team/coding-agent/skills/fetch-jira-issue/fetch_jira_issue.py OCPBUGS-12345 --format json

# Or get a human-readable summary
python3 team/coding-agent/skills/fetch-jira-issue/fetch_jira_issue.py OCPBUGS-12345 --format summary
```

**Prerequisites:**
- `JIRA_API_TOKEN` environment variable (set via systemd service)
- `JIRA_USERNAME` environment variable (set via systemd service)
- These are configured in `/home/splat/.botminter/workspaces/splat/team/systemd/botminter.env`

## What Context to Extract

When fetching Jira context, extract and incorporate:

1. **Summary**: Jira issue title/summary
2. **Description**: Full description/problem statement from Jira
3. **Components**: Affected components/areas
4. **Priority**: Priority level (Critical, Major, Minor, etc.)
5. **Labels**: Relevant labels (Regression, CustomerCase, etc.)
6. **Assignee**: Current assignee (if any)
7. **Status**: Current Jira status
8. **Comments**: Recent activity and context from comments
9. **Linked PRs**: Any GitHub PRs mentioned in Jira comments
10. **Fix Versions**: Target release versions

## Integration Into Epic Workflow

### During `po:triage` Phase

When the PO Backlog Manager (`po_backlog` hat) processes a new epic with a Jira reference:

1. **Extract Jira key** from epic issue body or title using pattern: `[A-Z]+-\d+`

2. **Fetch Jira details**:
   ```bash
   jira_data=$(python3 team/coding-agent/skills/fetch-jira-issue/fetch_jira_issue.py "$jira_key" --format json 2>/dev/null)
   ```

3. **Update epic issue body** to include Jira context:
   ```markdown
   ## Jira Reference
   
   **Jira Issue**: [OCPBUGS-12345](https://redhat.atlassian.net/browse/OCPBUGS-12345)
   **Status**: Modified
   **Priority**: Critical
   **Components**: Networking / cluster-network-operator
   **Assignee**: Jane Developer
   
   ### Jira Summary
   
   [Summary from Jira]
   
   ### Jira Description
   
   [Full description from Jira]
   
   ### Recent Jira Activity
   
   - [Recent comment 1]
   - [Recent comment 2]
   
   ### Linked PRs
   
   - https://github.com/openshift/repo/pull/123
   ```

4. **Add Jira reference to triage comment** for human context:
   ```markdown
   ### 📝 po — 2026-04-16T12:00:00Z
   
   **Triage request**
   
   New epic in triage based on Jira issue **OCPBUGS-12345**:
   
   **Jira Summary**: [title from Jira]
   **Priority**: Critical
   **Component**: Networking / cluster-network-operator
   **Current Status**: Modified (active work in progress)
   
   Recommendation: [your assessment incorporating Jira context]
   
   Please respond on this issue:
   - `Approved` — accept to backlog
   - `Rejected: <reason>` — close this epic
   ```

### During `arch:design` Phase

When the Architect (`arch_designer` hat) creates the design document:

1. **Reference Jira context** in the design doc introduction:
   ```markdown
   ## Problem Statement
   
   Based on Jira issue [OCPBUGS-12345](https://redhat.atlassian.net/browse/OCPBUGS-12345):
   
   [Problem description from Jira, refined/expanded as needed]
   ```

2. **Include relevant Jira details** in design decisions section if applicable

3. **Link to Jira PRs** if they provide implementation context

### Maintaining Jira Link

Throughout the epic lifecycle:

1. **Add Jira key as label** on the GitHub epic issue: `jira/OCPBUGS-12345`
2. **Reference Jira in story issues** created from the epic
3. **Cross-reference** by adding a comment on the Jira issue linking to the GitHub epic (optional, when appropriate)

## Error Handling

If Jira fetch fails:

1. **Check for credentials**:
   ```bash
   if [ -z "$JIRA_API_TOKEN" ] || [ -z "$JIRA_USERNAME" ]; then
     echo "Warning: JIRA credentials not configured. Proceeding without Jira context."
   fi
   ```

2. **Handle network/auth errors gracefully** - don't block epic creation
3. **Add note to epic** if Jira context couldn't be fetched:
   ```markdown
   > Note: Could not fetch Jira context for OCPBUGS-12345 (credentials not available or network error).
   > Please manually review: https://redhat.atlassian.net/browse/OCPBUGS-12345
   ```

## Benefits

- **Richer context** for design and planning decisions
- **Traceability** between Jira tracking and GitHub implementation
- **Priority alignment** - Jira priority informs epic prioritization
- **Assignee visibility** - know who's working on related Jira issue
- **PR discovery** - find related implementation work already in progress
- **Customer impact** - surface customer-facing issues via Jira labels

## Example: Epic Creation Flow

**Human creates epic:**
```markdown
Title: Fix OVN IPSec duplicate attribute issue
Body: 
Jira: OCPBUGS-74401

[Additional context from human]
```

**Agent processes during po:triage:**
1. Detects `OCPBUGS-74401` in body
2. Fetches Jira details using `fetch-jira-issue` skill
3. Enriches epic issue with Jira context
4. Posts triage comment with Jira summary
5. Human approves → moves to backlog → proceeds to design

**Result:**
- Epic has full Jira context embedded
- Designer has problem statement, components, priority
- Stories can reference upstream Jira issue
- Better-informed technical decisions
