---
name: Update Enhancement Document
description: Review and update epic design docs based on merged PR implementations
---

# Update Enhancement Document

After a PR merges, review the parent epic's enhancement document (design doc) and update it to reflect what was actually implemented, including deviations from the original design and lessons learned.

## When to Use This Skill

Use this skill when:
- A story's PR has been merged to upstream (openshift/*)
- Story status advances to `done`
- Need to keep the epic's design doc accurate and up-to-date

## Prerequisites

1. **Story is done** - PR merged and story closed
2. **Parent epic exists** - story references a parent epic
3. **Design doc exists** - epic has a design document at `team/projects/<project>/knowledge/designs/epic-<N>.md`

## Workflow

### Step 1: Identify the Parent Epic and Design Doc

```bash
STORY_NUM="${1:-}"
TEAM_REPO=$(cd team && git remote get-url origin | sed 's|.*github.com[:/]||;s|\.git$||')

# Get story details
STORY_DATA=$(gh issue view "$STORY_NUM" --repo "$TEAM_REPO" --json title,body,labels,closedAt)

# Extract parent epic number from story body
EPIC_NUM=$(echo "$STORY_DATA" | jq -r '.body' | grep -oP 'Parent: #\K\d+' || echo "")

if [ -z "$EPIC_NUM" ]; then
  echo "No parent epic found for story #${STORY_NUM}"
  exit 0
fi

# Get epic details
EPIC_DATA=$(gh issue view "$EPIC_NUM" --repo "$TEAM_REPO" --json title,labels)
EPIC_TITLE=$(echo "$EPIC_DATA" | jq -r '.title')

# Find project from labels
PROJECT=$(echo "$EPIC_DATA" | jq -r '.labels[] | select(.name | startswith("project/")) | .name' | sed 's|project/||')

if [ -z "$PROJECT" ]; then
  echo "No project label found for epic #${EPIC_NUM}"
  exit 0
fi

# Locate design doc
DESIGN_DOC="team/projects/${PROJECT}/knowledge/designs/epic-${EPIC_NUM}.md"

if [ ! -f "$DESIGN_DOC" ]; then
  echo "Design doc not found: $DESIGN_DOC"
  exit 0
fi

echo "Found design doc: $DESIGN_DOC for epic #${EPIC_NUM}"
```

### Step 2: Check if PR Was Merged

```bash
# Get the story's PR number from issue comments or body
PR_URL=$(echo "$STORY_DATA" | jq -r '.body' | grep -oP 'https://github.com/openshift/[^/]+/pull/\d+' | head -1)

if [ -z "$PR_URL" ]; then
  echo "No upstream PR found for story #${STORY_NUM}"
  exit 0
fi

# Extract PR details from URL
UPSTREAM_REPO=$(echo "$PR_URL" | sed 's|https://github.com/\([^/]*/[^/]*\)/pull/.*|\1|')
PR_NUM=$(echo "$PR_URL" | grep -oP 'pull/\K\d+')

# Check PR merge status
PR_STATUS=$(gh pr view "$PR_NUM" --repo "$UPSTREAM_REPO" --json state,mergedAt,merged --jq '{state, mergedAt, merged}')
MERGED=$(echo "$PR_STATUS" | jq -r '.merged')
MERGED_AT=$(echo "$PR_STATUS" | jq -r '.mergedAt')

if [ "$MERGED" != "true" ]; then
  echo "PR $PR_URL not yet merged"
  exit 0
fi

echo "PR merged at: $MERGED_AT"
```

### Step 3: Review the Merged Implementation

```bash
# Get PR details including files changed and commit messages
PR_DETAILS=$(gh pr view "$PR_NUM" --repo "$UPSTREAM_REPO" --json title,body,files,commits)

# Extract implementation summary
PR_TITLE=$(echo "$PR_DETAILS" | jq -r '.title')
PR_BODY=$(echo "$PR_DETAILS" | jq -r '.body')

# Get list of files changed
FILES_CHANGED=$(echo "$PR_DETAILS" | jq -r '.files[] | .path' | head -20)

# Get commit messages
COMMIT_MESSAGES=$(echo "$PR_DETAILS" | jq -r '.commits[] | .commit.message' | head -20)

echo "Implementation review:"
echo "  Files changed: $(echo "$FILES_CHANGED" | wc -l)"
echo "  Commits: $(echo "$PR_DETAILS" | jq -r '.commits | length')"
```

### Step 4: Read Current Design Doc

```bash
# Read the existing design doc
CURRENT_DESIGN=$(cat "$DESIGN_DOC")

# Extract key sections to compare
echo "Current design sections:"
grep -E '^##' "$DESIGN_DOC" || echo "No sections found"
```

### Step 5: Determine Updates Needed

Compare the design doc with what was actually implemented:

1. **Architecture deviations** - Did the implementation differ from the design?
2. **New components** - Were additional components added that weren't in the design?
3. **Simplified/removed components** - Were planned components not needed?
4. **API/interface changes** - Did the actual APIs differ from the design?
5. **Implementation notes** - Important details about how it was implemented
6. **Lessons learned** - What was discovered during implementation?

### Step 6: Update the Design Doc

Add an "Implementation Notes" section (or update if it exists):

```bash
# Check if Implementation Notes section exists
if grep -q "^## Implementation Notes" "$DESIGN_DOC"; then
  # Section exists, append to it
  echo "Updating existing Implementation Notes section"
else
  # Add new section at the end
  echo "Adding new Implementation Notes section"
  cat >> "$DESIGN_DOC" <<EOF

## Implementation Notes

### Story #${STORY_NUM}: ${STORY_TITLE}

**Merged:** ${MERGED_AT}  
**PR:** ${PR_URL}

**Implementation Summary:**
${IMPLEMENTATION_SUMMARY}

**Deviations from Design:**
${DEVIATIONS}

**Lessons Learned:**
${LESSONS_LEARNED}

EOF
fi
```

## Update Templates

### Template 1: Straightforward Implementation (No Deviations)

```markdown
## Implementation Notes

### Story #18: API Extensions and Credential Schema

**Merged:** 2026-04-24T18:00:00Z  
**PR:** https://github.com/openshift/installer/pull/123

**Implementation Summary:**
Implemented as designed. Added credential validation APIs, schema extensions, and integration tests as specified.

**Files Changed:**
- `pkg/infrastructure/vsphere/credentials.go` - Validation logic
- `pkg/types/vsphere/credentials.go` - Schema definitions
- `pkg/infrastructure/vsphere/credentials_test.go` - Unit tests
- `pkg/infrastructure/vsphere/provision_test.go` - Integration test stubs

**Test Coverage:**
- 14 unit tests added (100% coverage on new code)
- 14 integration test stubs (pending govcsim infrastructure)

**No deviations from original design.**
```

### Template 2: With Deviations

```markdown
## Implementation Notes

### Story #19: Multi-vCenter Support

**Merged:** 2026-04-25T14:30:00Z  
**PR:** https://github.com/openshift/machine-api-operator/pull/456

**Implementation Summary:**
Implemented multi-vCenter credential management with connection pooling and failover handling.

**Deviations from Design:**

1. **Connection Pooling Simplified**
   - Design called for per-datacenter connection pools
   - Implementation uses single global pool with region keys
   - Rationale: Simpler implementation, no performance difference in testing

2. **Error Handling Enhanced**
   - Added retry logic not in original design
   - Needed to handle transient vSphere API failures
   - Uses exponential backoff (3 retries, 1s/2s/4s)

3. **Configuration Format Changed**
   - Original: flat list of vCenter configs
   - Implemented: hierarchical region → vCenter mapping
   - Rationale: Better aligns with existing OpenShift region concepts

**Lessons Learned:**

- vSphere API connection establishment is slow (~500ms), connection pooling critical
- Region-based credential selection works better than datacenter-based
- govcsim limitations prevented full integration testing, real vSphere lab required

**Files Changed:**
- `pkg/vsphere/actuator/actuator.go` - Core implementation
- `pkg/vsphere/credentials/pool.go` - Connection pooling (new)
- `pkg/apis/vsphere/v1/types.go` - Schema changes
- 8 test files (~1200 lines of test coverage)
```

### Template 3: Partial Implementation

```markdown
## Implementation Notes

### Story #20: Cloud Credential Operator Integration

**Merged:** 2026-04-26T10:15:00Z  
**PR:** https://github.com/openshift/cloud-credential-operator/pull/789

**Implementation Summary:**
Implemented CCO integration with credential rotation support.

**Partial Implementation:**

✅ **Completed:**
- Basic credential provisioning
- Credential validation and health checks
- Manual credential rotation via API

⚠️ **Deferred to Future Story:**
- Automatic credential rotation (requires operator upgrade framework changes)
- Credential expiry monitoring (needs Prometheus metrics infrastructure)

**Rationale for Deferral:**
Operator upgrade framework changes required for automatic rotation are blocked on upstream OpenShift decision. Manual rotation via API satisfies the core use case. Automatic rotation will be added in Story #28.

**Files Changed:**
- `pkg/operator/credentialsrequest/vsphere/actuator.go`
- `pkg/vsphere/credentials/rotator.go` (manual rotation only)
- 15 test files

**Dependencies for Future Work:**
- Upstream: operator-framework credential rotation API (tracking in OCPBUGS-12345)
- Infrastructure: Prometheus metrics endpoint (Story #27)
```

## Integration with Workflow

This skill should be called:

1. **When story status changes to `done`**
   - Check if upstream PR exists and is merged
   - If merged, update the design doc

2. **During epic `po:accept` review**
   - Review all story implementation notes
   - Summarize overall implementation vs design
   - Add epic-level lessons learned

## Automation Integration

Add to `po_merger` hat or create new `doc_updater` hat:

```yaml
doc_updater:
  name: Documentation Updater
  description: Updates enhancement documents based on merged implementations
  triggers:
    - story.merged
  instructions: |
    When a story's PR merges, update the parent epic's design doc.
    
    1. Load the update-enhancement-doc skill
    2. Check if story has merged PR
    3. Review implementation vs design
    4. Update design doc with implementation notes
    5. Commit changes to team repo
```

## Best Practices

1. **Be specific** - Don't just say "implemented as designed", note actual files/components
2. **Document deviations** - Explain why implementation differs from design
3. **Capture lessons** - What did you learn that would help future similar work?
4. **Link PRs** - Always include upstream PR URL for traceability
5. **Update promptly** - Do this right after merge while details are fresh

## Example: Full Workflow

```bash
#!/bin/bash
# Update enhancement doc for story #18

STORY_NUM=18
TEAM_REPO="openshift-splat-team/splat-team"

# Get parent epic
EPIC_NUM=$(gh issue view "$STORY_NUM" --repo "$TEAM_REPO" --json body --jq '.body' | grep -oP 'Parent: #\K\d+')
echo "Parent epic: #${EPIC_NUM}"

# Find design doc
PROJECT="installer"
DESIGN_DOC="team/projects/${PROJECT}/knowledge/designs/epic-${EPIC_NUM}.md"

# Get PR details
PR_URL="https://github.com/openshift/installer/pull/123"
PR_NUM=123
PR_DATA=$(gh pr view "$PR_NUM" --repo "openshift/installer" --json title,mergedAt,files,commits)

MERGED_AT=$(echo "$PR_DATA" | jq -r '.mergedAt')
FILES=$(echo "$PR_DATA" | jq -r '.files[].path' | wc -l)

# Generate implementation notes
cat >> "$DESIGN_DOC" <<EOF

## Implementation Notes

### Story #18: API Extensions and Credential Schema

**Merged:** ${MERGED_AT}  
**PR:** ${PR_URL}

**Implementation Summary:**
Implemented credential validation APIs and schema extensions as designed.

**Files Changed:** ${FILES} files
- pkg/infrastructure/vsphere/credentials.go
- pkg/types/vsphere/credentials.go
- pkg/infrastructure/vsphere/*_test.go

**Test Coverage:** 28 tests added (14 unit, 14 integration stubs)

**No deviations from design.** Implementation followed enhancement proposal exactly.

EOF

# Commit update
git add "$DESIGN_DOC"
git commit -m "docs: Update epic-${EPIC_NUM} design with story #${STORY_NUM} implementation notes

Added implementation notes from merged PR ${PR_URL}

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

git push
```

This skill ensures design docs stay synchronized with reality and capture valuable implementation insights! 📝
