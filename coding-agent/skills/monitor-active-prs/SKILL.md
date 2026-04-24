---
name: Monitor Active PRs
description: Check all active staging PRs for review comments and trigger responses
auto_inject: true
---

# Monitor Active PRs

Scan all active staging PRs in openshift-splat-team forks for review comments and trigger appropriate responses.

## Purpose

This skill is called by the board scanner to check PRs in parallel with issue scanning. It ensures that review feedback is addressed promptly.

## When It Runs

- Called during every board scan cycle (typically every scan)
- Auto-injected into the coordinator's context
- Runs for all projects with active stories that have PRs

## What It Does

1. **Find Active PRs** - Lists all open PRs in staging forks
2. **Check for Feedback** - Looks for:
   - Reviews with "CHANGES_REQUESTED" state
   - Inline review comments (code-level feedback)
   - PR-level comments (general discussions)
3. **Emit Events** - Triggers dev.pr-feedback for PRs needing response

## Implementation

### Step 1: Find All Active PRs

```bash
# Get all projects
PROJECTS=(
  "cloud-credential-operator"
  "cluster-cloud-controller-manager-operator"
  "cluster-storage-operator"
  "installer"
  "machine-api-operator"
  "vcf-migration-operator"
)

# Check each project for open PRs
for project in "${PROJECTS[@]}"; do
  gh pr list \
    --repo "openshift-splat-team/${project}" \
    --state open \
    --json number,headRefName,updatedAt,reviewDecision
done
```

### Step 2: Check Each PR for Feedback

```bash
check_pr_feedback() {
  local project=$1
  local pr_num=$2
  
  # Get PR details
  PR_DATA=$(gh pr view "$pr_num" \
    --repo "openshift-splat-team/${project}" \
    --json reviews,comments,headRefName,updatedAt)
  
  # Extract branch name (should be story-N-xxx)
  BRANCH=$(echo "$PR_DATA" | jq -r '.headRefName')
  STORY_NUM=$(echo "$BRANCH" | grep -oP 'story-\K\d+' || echo "")
  
  if [ -z "$STORY_NUM" ]; then
    echo "Skipping PR #${pr_num} - not a story branch"
    return
  fi
  
  # Check for changes requested
  CHANGES_REQUESTED=$(echo "$PR_DATA" | jq '
    [.reviews[] | select(.state == "CHANGES_REQUESTED")] | 
    sort_by(.submittedAt) | 
    reverse | 
    .[0]
  ')
  
  if [ "$CHANGES_REQUESTED" != "null" ]; then
    REVIEWER=$(echo "$CHANGES_REQUESTED" | jq -r '.author.login')
    REVIEW_TIME=$(echo "$CHANGES_REQUESTED" | jq -r '.submittedAt')
    
    # Check if already responded
    LAST_RESPONSE=$(echo "$PR_DATA" | jq -r '
      [.comments[] | 
       select(.author.login == "splat-sdlc-agent[bot]") |
       select(.body | contains("Feedback Addressed") or contains("Working on"))] |
      sort_by(.createdAt) |
      reverse |
      .[0].createdAt // empty
    ')
    
    if [ -z "$LAST_RESPONSE" ] || [ "$REVIEW_TIME" \> "$LAST_RESPONSE" ]; then
      echo "PR #${pr_num} (story #${STORY_NUM}) has unaddressed feedback from @${REVIEWER}"
      
      # Emit event to trigger response
      ralph tools pubsub publish dev.pr-feedback \
        "story=${STORY_NUM}, project=${project}, pr=${pr_num}, reviewer=${REVIEWER}"
      
      return 0
    fi
  fi
  
  # Check for inline review comments (from /pulls/:pull_number/comments)
  REVIEW_COMMENTS=$(gh api "repos/openshift-splat-team/${project}/pulls/${pr_num}/comments" \
    --jq '[.[] | select(.user.login != "splat-sdlc-agent[bot]")] | length')
  
  if [ "$REVIEW_COMMENTS" -gt 0 ]; then
    # Get the most recent review comment
    LATEST_REVIEW_COMMENT=$(gh api "repos/openshift-splat-team/${project}/pulls/${pr_num}/comments" \
      --jq '[.[] | select(.user.login != "splat-sdlc-agent[bot]")] | sort_by(.created_at) | reverse | .[0]')
    
    REVIEWER=$(echo "$LATEST_REVIEW_COMMENT" | jq -r '.user.login')
    COMMENT_TIME=$(echo "$LATEST_REVIEW_COMMENT" | jq -r '.created_at')
    
    # Check if already responded to this review comment
    LAST_RESPONSE=$(echo "$PR_DATA" | jq -r '
      [.comments[] | 
       select(.author.login == "splat-sdlc-agent[bot]") |
       select(.body | contains("@'"$REVIEWER"'"))] |
      sort_by(.createdAt) |
      reverse |
      .[0].createdAt // empty
    ')
    
    if [ -z "$LAST_RESPONSE" ] || [ "$COMMENT_TIME" \> "$LAST_RESPONSE" ]; then
      echo "PR #${pr_num} (story #${STORY_NUM}) has ${REVIEW_COMMENTS} inline review comment(s) from @${REVIEWER}"
      
      # Emit event to trigger response
      ralph tools pubsub publish dev.pr-feedback \
        "story=${STORY_NUM}, project=${project}, pr=${pr_num}, reviewer=${REVIEWER}"
      
      return 0
    fi
  fi
  
  # Check for PR-level comments (questions/discussions on the PR itself)
  RECENT_COMMENTS=$(echo "$PR_DATA" | jq -r '
    [.comments[] | 
     select(.author.login != "splat-sdlc-agent[bot]") |
     select(.body | length > 10)] |
    length
  ')
  
  if [ "$RECENT_COMMENTS" -gt 0 ]; then
    echo "PR #${pr_num} (story #${STORY_NUM}) has ${RECENT_COMMENTS} PR-level comment(s)"
    
    # Emit event for discussion monitoring
    ralph tools pubsub publish dev.pr-discussion \
      "story=${STORY_NUM}, project=${project}, pr=${pr_num}, comments=${RECENT_COMMENTS}"
  fi
}
```

### Step 3: Scan All Projects

```bash
scan_all_prs() {
  echo "=== Scanning Active PRs for Feedback ==="
  
  local feedback_count=0
  
  for project in "${PROJECTS[@]}"; do
    # Get open PRs
    PRS=$(gh pr list \
      --repo "openshift-splat-team/${project}" \
      --state open \
      --json number \
      --jq '.[].number')
    
    if [ -z "$PRS" ]; then
      continue
    fi
    
    for pr in $PRS; do
      if check_pr_feedback "$project" "$pr"; then
        ((feedback_count++))
      fi
    done
  done
  
  if [ $feedback_count -eq 0 ]; then
    echo "No unaddressed PR feedback found"
  else
    echo "Found $feedback_count PRs with unaddressed feedback"
  fi
}
```

## Integration with Board Scanner

The board scanner should call this skill after checking issues:

```bash
# In board-scanner procedure
echo "Scanning GitHub project board..."
# ... existing board scan logic ...

echo "Scanning active PRs for feedback..."
ralph tools skill load monitor-active-prs
scan_all_prs

# Continue with hat delegation...
```

## Event Flow

When unaddressed feedback is found:

```
monitor-active-prs detects feedback
    ↓
Publishes: dev.pr-feedback
    ↓
dev_implementer hat receives event
    ↓
Loads pr-feedback-monitor skill
    ↓
Responds to feedback (3-step workflow)
    ↓
Updates PR and notifies reviewer
```

## Integration with dev_implementer Hat

The `dev_implementer` hat should listen for `dev.pr-feedback` events:

```yaml
dev_implementer:
  triggers:
    - dev.implement
    - dev.rejected
    - qe.rejected
    - dev.pr-feedback  # NEW: Respond to PR feedback
```

When triggered by `dev.pr-feedback`, the hat should:
1. Load `pr-feedback-monitor` skill
2. Parse the feedback
3. Follow the 3-step response workflow
4. Update the PR and request re-review

## Output Format

```json
{
  "activePRs": 6,
  "prsWithFeedback": 2,
  "feedbackItems": [
    {
      "project": "cloud-credential-operator",
      "pr": 3,
      "story": 25,
      "reviewer": "human-reviewer",
      "feedbackType": "changes-requested",
      "reviewedAt": "2026-04-24T18:30:00Z",
      "lastResponse": null,
      "needsAction": true
    }
  ]
}
```

## Monitoring

To manually check PR status:

```bash
# Load and run the skill
ralph tools skill load monitor-active-prs
scan_all_prs

# Check specific PR
check_pr_feedback "cloud-credential-operator" 3
```

## Notes

- Runs automatically during board scan (if auto_inject: true)
- Only checks openshift-splat-team/* staging forks
- Does not check upstream openshift/* PRs
- Idempotent - won't trigger duplicate responses
- Emits events that dev_implementer can handle

This skill ensures that PR feedback is never missed and responses are timely! 🚀
