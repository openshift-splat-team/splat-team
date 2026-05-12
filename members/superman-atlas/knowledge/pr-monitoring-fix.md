# PR Monitoring Fixes

## Problem 1: Duplicate Processing

The `monitor-active-prs` skill processes the same PRs multiple times even when they have no new updates.

**Root cause:** The idempotency check on lines 88-95 of `monitor-active-prs/SKILL.md` only looks for bot comments containing the exact phrases "Feedback Addressed" or "Working on":

```bash
LAST_RESPONSE=$(echo "$PR_DATA" | jq -r '
  [.comments[] | 
   select(.author.login == "splat-sdlc-agent[bot]") |
   select(.body | contains("Feedback Addressed") or contains("Working on"))] |
  sort_by(.createdAt) |
  reverse |
  .[0].createdAt // empty
')
```

If the bot responds with different wording, this check fails and the PR gets re-processed on every board scan cycle.

## Solution

Replace the phrase-specific check with a more robust check that looks for **ANY** bot comment posted after the review time:

```bash
# Check if already responded
LAST_RESPONSE=$(echo "$PR_DATA" | jq -r '
  [.comments[] | 
   select(.author.login == "splat-sdlc-agent[bot]") |
   select(.createdAt > "'"$REVIEW_TIME"'")] |
  length
')

if [ "$LAST_RESPONSE" -gt 0 ]; then
  echo "Already responded to review from @${REVIEWER} at ${REVIEW_TIME}"
  return 1
fi
```

This checks if **any** bot comment exists after the review timestamp. If yes, we've already responded and should skip this PR.

## Alternative: Track Processing State

For more robust deduplication, maintain a state file:

```bash
# At start of scan_all_prs
PROCESSED_STATE_FILE="team/members/superman-atlas/.processed-prs.json"
touch "$PROCESSED_STATE_FILE"

# Before emitting dev.pr-feedback
PR_KEY="${project}:${pr_num}:${REVIEW_TIME}"

if jq -e --arg key "$PR_KEY" '.processed | contains([$key])' "$PROCESSED_STATE_FILE" > /dev/null; then
  echo "Already processed PR #${pr_num} review at ${REVIEW_TIME}"
  return 1
fi

# After emitting dev.pr-feedback
jq --arg key "$PR_KEY" '.processed += [$key]' "$PROCESSED_STATE_FILE" > tmp && mv tmp "$PROCESSED_STATE_FILE"
```

This tracks `project:pr_number:review_timestamp` combinations and prevents duplicate processing even if the bot's response comment doesn't get recognized.

## Recommendation

Use the **first solution** (check for any bot comment after review time) as it's simpler and leverages existing comment data. Add the state file approach only if issues persist.

## Implementation

Edit `/home/splat/.botminter/workspaces/splat/team/coding-agent/skills/monitor-active-prs/SKILL.md`:

1. Find the `check_pr_feedback()` function
2. Replace lines 88-95 (the LAST_RESPONSE check)
3. Update the condition on line 97 to use the new check logic

Apply similar fixes to:
- The inline review comments check (lines 120-128)
- The PR-level comments check (if needed)

## Problem 2: Missing Post-Merge Feedback

The skill only checked `--state open` PRs, missing feedback on recently merged PRs.

**Impact:**
- Post-merge comments were ignored (security concerns, late reviews, etc.)
- PRs associated with "done" stories were not monitored
- Follow-up discussions after merge were missed

## Solution 2: Monitor Recently Merged PRs

Updated `scan_all_prs()` to also check merged PRs from the last 7 days:

```bash
# Get recently merged PRs (last 7 days) - may still have active discussion
MERGED_PRS=$(gh pr list \
  --repo "openshift-splat-team/${project}" \
  --state merged \
  --search "merged:>$(date -d '7 days ago' +%Y-%m-%d)" \
  --json number \
  --jq '.[].number' 2>/dev/null || echo "")

# Combine both lists
ALL_PRS="$OPEN_PRS $MERGED_PRS"
```

**Why 7 days?**
- Balances completeness with performance
- Most post-merge feedback arrives within a week
- Prevents scanning thousands of old PRs
- Can be adjusted if needed

**Key principle:** Story status is independent of PR monitoring. Even if a story is marked "done", its PR should still be monitored for important feedback.
