# Documentation Workflow

## When to Create Documentation Issues

Create a separate `kind/docs` issue when:
- An epic introduces new features that require user-facing documentation
- An epic changes existing behavior that affects documented workflows
- The epic spans multiple stories and needs consolidated documentation

## Documentation Issue Creation

When wearing the **architect** hat during `arch:breakdown`:

1. Identify if the epic requires documentation
2. Create a `kind/docs` issue with:
   - Title: `[Docs] <Epic Title>`
   - Label: `kind/docs`
   - Parent: Link to the epic (`parent/<epic-number>`)
   - Body: List all stories from the epic and what needs documenting

Example:

```markdown
## Scope

This documentation issue covers all work from Epic #42 (Feature X Implementation):
- Story #43: Backend API implementation
- Story #44: Frontend UI changes
- Story #45: CLI updates

## Documentation Requirements

- Update MkDocs user guide with Feature X usage
- Add configuration examples
- Document API endpoints
- Add troubleshooting section

## Target Repository

- Repo: openshift-splat-team/splat-team
- Branch: docs/feature-x
- Format: MkDocs
```

## Documentation Lifecycle

| Status | What Happens |
|--------|--------------|
| `cw:write` | Write MkDocs content in splat-team repo branch |
| `cw:review` | Review and revise documentation |
| `cw:merge-ready` | Create PR in splat-team repo, ready for merge |
| `po:merge` | Auto-advance (merge PR) |
| `done` | Documentation published |

## Epic Completion Dependency

**IMPORTANT:** An epic should NOT transition to `done` until all associated `kind/docs` issues are complete.

When wearing the **architect** hat at `arch:in-progress`:
- Check if the epic has linked documentation issues
- Only fast-forward to `po:accept` when ALL child issues (including docs) are `done`

## Writing Documentation (Content Writer Hat)

At `cw:write` status:

1. Clone or pull `openshift-splat-team/splat-team` repo
2. Create a feature branch: `docs/<epic-slug>`
3. Write MkDocs content covering all work from the epic
4. Reference the parent epic and child stories for context
5. Transition to `cw:review` when draft is complete

At `cw:review` status:

1. Review documentation for:
   - Completeness (all epic work covered)
   - Accuracy (matches implemented behavior)
   - Clarity (user-friendly language)
   - Format (valid MkDocs syntax)
2. Make revisions as needed
3. Transition to `cw:merge-ready` when review passes

At `cw:merge-ready` status:

1. Push branch to remote
2. Create PR in splat-team repo
3. Link PR in issue comment
4. Transition to `po:merge` (auto-advance to `done`)
