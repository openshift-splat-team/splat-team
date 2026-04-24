# CodeRabbit Integration Test Guide

## Quick Test

To verify CodeRabbit is working for superman's reviews:

### 1. Test CodeRabbit CLI

```bash
# Check authentication
coderabbit auth status

# Test review on current workspace
cd /home/splat/.botminter/workspaces/splat/superman-atlas/team-repo
coderabbit review --agent --type committed
```

### 2. Test with Team Config

```bash
# Use team configuration
cd /home/splat/.botminter/workspaces/splat/superman-atlas/team-repo
coderabbit review --agent --config ../team/coderabbit.yaml --type committed
```

### 3. Verify Skill is Accessible

From within a Ralph session (or via bm chat):

```bash
ralph tools skill load coderabbit-review
ralph tools skill list | grep coderabbit
```

### 4. Test Full Review Workflow

Create a test PR and let superman review it:

1. Make a code change in a story branch
2. Commit the change
3. Trigger superman's code review (it should automatically use CodeRabbit)
4. Check the review comment for CodeRabbit findings

## Expected Behavior

When superman wears the `dev_code_reviewer` hat:

1. ✅ Loads `coderabbit-review` skill
2. ✅ Runs `coderabbit review --agent --base main --config team/coderabbit.yaml`
3. ✅ Parses JSON findings
4. ✅ Makes approve/reject decision based on error count
5. ✅ Posts structured comment with CodeRabbit findings
6. ✅ Advances or rejects the story based on review

## Troubleshooting

### "CodeRabbit not authenticated"

```bash
coderabbit auth login
```

### "Skill not found"

Check that the skill exists:
```bash
ls /home/splat/.botminter/workspaces/splat/team/coding-agent/skills/coderabbit-review/
```

### "No changes to review"

CodeRabbit requires actual code changes:
```bash
git status
git log --oneline -5
```

### Superman not using CodeRabbit

Check that the knowledge file is accessible:
```bash
cat /home/splat/.botminter/workspaces/splat/team/members/superman-atlas/hats/dev_code_reviewer/knowledge/coderabbit-integration.md
```

## Manual Test Example

```bash
# Navigate to team repo workspace
cd /home/splat/.botminter/workspaces/splat/superman-atlas/team-repo

# Checkout a story branch
git checkout story-16-api-extensions

# Run CodeRabbit with team config
coderabbit review --agent \
  --base main \
  --config ../team/coderabbit.yaml \
  --type committed > /tmp/test-review.json

# Check results
cat /tmp/test-review.json | jq '.summary'
cat /tmp/test-review.json | jq '.findings[] | select(.severity == "error")'
```

## Success Criteria

✅ CodeRabbit CLI authenticated  
✅ Team config file exists at `team/coderabbit.yaml`  
✅ Skill available at `team/coding-agent/skills/coderabbit-review/`  
✅ Knowledge file exists for `dev_code_reviewer` hat  
✅ Superman can load and use the skill  
✅ Reviews produce structured JSON output  
✅ Reviews include team-specific rules  

## Next Steps

Once verified, superman will automatically use CodeRabbit for all code reviews when wearing the `dev_code_reviewer` hat.

No manual intervention needed - the workflow is fully automated!
