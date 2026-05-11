---
name: notify-slack
description: >-
  Post a progress notification to the team Slack channel via webhook.
  Call after completing meaningful work: PR feedback addressed, story
  advanced, epic status changed, or blocking issues encountered.
---

# Notify Slack

Post a concise update to the Slack webhook configured in `SLACK_WEBHOOK_URL`.

## When to Call

Call this skill after completing any of the following:
- PR review feedback acknowledged or addressed
- Story status advanced (e.g. dev:implement → dev:code-review → qe:verify → done)
- Epic status advanced (e.g. arch:design → lead:design-review → po:design-review)
- Human gate reached (waiting for approval on issue or PR)
- Blocking error encountered (3 failures, set to `error` status)

Do NOT call for every LOOP_COMPLETE or when nothing changed.

## Usage

```bash
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"

if [ -z "$SLACK_WEBHOOK_URL" ]; then
  echo "SLACK_WEBHOOK_URL not set — skipping Slack notification"
  return 0
fi

notify_slack() {
  local message="$1"
  curl -s -X POST "$SLACK_WEBHOOK_URL" \
    -H 'Content-Type: application/json' \
    -d "{\"text\": \"${message}\"}" \
    > /dev/null
}
```

## Message Format

Keep messages short and actionable. Use this pattern:

```
🤖 *superman-atlas* | <emoji> <what happened> | <link>
```

### Examples by event type

**PR feedback addressed:**
```bash
notify_slack "🤖 *superman-atlas* | ✅ Addressed PR feedback from @rvanderp3 on PR #7 (story #37 — privilege validation) | https://github.com/openshift-splat-team/cloud-credential-operator/pull/7"
```

**Story advanced:**
```bash
notify_slack "🤖 *superman-atlas* | 🔄 Story #37 advanced: \`dev:implement\` → \`dev:code-review\` | https://github.com/openshift-splat-team/splat-team/issues/37"
```

**Human gate reached:**
```bash
notify_slack "🤖 *superman-atlas* | 👤 Waiting for human review on epic #33 design doc | https://github.com/openshift-splat-team/splat-team/pull/34"
```

**Story done:**
```bash
notify_slack "🤖 *superman-atlas* | ✅ Story #37 complete | https://github.com/openshift-splat-team/splat-team/issues/37"
```

**Blocking error:**
```bash
notify_slack "🤖 *superman-atlas* | ❌ Issue #37 failed 3 times — set to \`error\` status, needs investigation | https://github.com/openshift-splat-team/splat-team/issues/37"
```

## Escaping

Escape double quotes and backslashes in the message before passing to curl.
Keep messages under 200 characters. Do not include raw JSON or code blocks.
