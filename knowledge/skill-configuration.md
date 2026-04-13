# Skill Configuration Guide

This document explains how to configure and use the transferred skills from ai-helpers in your team workspace.

## Skills Location

All transferred skills are located in `team/coding-agent/skills/`. Ralph automatically discovers and loads skills from configured directories.

## Ralph Configuration

Skills are configured in the workspace's `ralph.yml` file via the `skills.dirs` setting:

```yaml
skills:
  dirs:
    - team/coding-agent/skills          # Team-level skills (available to all)
    - team/projects/<project>/coding-agent/skills   # Project-specific skills
    - team/members/superman/coding-agent/skills     # Member-specific skills
```

### Configuration Hierarchy

Skills are loaded from multiple scopes, in order of specificity:

1. **Team skills** - `team/coding-agent/skills/` (applies to all members and projects)
2. **Project skills** - `team/projects/<project>/coding-agent/skills/` (applies to specific project)
3. **Member skills** - `team/members/superman/coding-agent/skills/` (member-specific)
4. **Hat skills** - `team/members/superman/hats/<hat>/coding-agent/skills/` (hat-specific)

All applicable scopes are additive - skills from all levels are available.

## Skill Categories

The 74 transferred skills are organized into these functional domains:

### JIRA Management (18 skills)

For issue tracking and workflow:
- Issue creation: `create-bug`, `create-epic`, `create-feature`, `create-story`, `create-task`
- Analysis: `status-analysis`, `categorize-activity-type`, `jira-validate-blockers`
- Documentation: `jira-doc-generator`, `create-release-note`, `generate-enhancement`
- Project conventions: `ocpbugs`, `cntrlplane`, `hypershift`, `gcp-hcp`
- Utilities: `extract-prs`, `jira-issues-by-component`

### CI/CD Operations (26 skills)

For OpenShift CI, Prow jobs, and payload management:
- Payload analysis: `analyze-payload`, `fetch-payloads`, `fetch-new-prs-in-payload`
- Prow job analysis: `prow-job-analyze-*` (install-failure, test-failure, resource, etc.)
- Test operations: `fetch-test-report`, `fetch-test-runs`, `fetch-regression-details`
- Regression triage: `triage-regression`, `fetch-related-triages`
- Revert management: `revert-pr`, `stage-payload-reverts`, `payload-experimental-reverts`
- Job triggering: `trigger-payload-job`
- Utilities: `oc-auth`, `set-release-blocker`, `prow-job-artifact-search`

### SDLC Orchestration (8 skills)

Complete software development lifecycle automation:
- `phase-design` - Create implementation specification
- `phase-enhancement` - Generate enhancement proposals
- `phase-implementation` - Execute code changes
- `phase-testing` - Run test suite and validate coverage
- `phase-pr-review` - Create comprehensive PR
- `phase-merge` - Monitor PR merge and deployment
- `phase-completion` - Update Jira and verify deployment
- `sdlc-state-yaml` - State management (required for SDLC)

### Team Health (15 skills)

Component health monitoring and analysis:
- Health checks: `health-check`, `health-check-jiras`, `health-check-regressions`
- Analysis: `analyze-regressions`
- Repository management: `list-repos`, `find-repo-owner`
- Component management: `list-components`, `list-jiras`, `list-regressions`
- CodeRabbit: `coderabbit-adoption`, `coderabbit-inheritance-scanner-*`, `coderabbit-rules-from-pr-reviews`

### Code Quality (2 skills)

Automated code review:
- `pr-review` - PR code quality review with language-aware analysis
- `pre-commit-review` - Pre-commit code quality review

### Testing (2 skills)

Test analysis and improvement:
- `mutation-test` - Operator controller quality testing via mutation
- `test-structure-only` - Analyze test code structure for coverage gaps

### OpenShift & Git (3 skills)

Platform and repository utilities:
- `cluster-health` - OpenShift cluster health check
- `om-bootstrap` - Bootstrap OpenShift Manager integration
- `debt-scan` - Analyze technical debt in repository

## Agent Configuration

Two agents were also transferred:

### feedback Agent

**Location:** `team/coding-agent/agents/feedback.md`

General feedback collection and processing agent.

### step-registry-analyzer Agent

**Location:** `team/coding-agent/agents/step-registry-analyzer.md`

CI-specific agent for understanding OpenShift CI components (workflows, chains, refs).

**Usage:** Automatically available via `subagent_type: "ci:step-registry-analyzer"` in Agent tool calls.

## Accessing Skills

### Via SKILL.md Files

Each skill has a `SKILL.md` file that defines:
- Skill purpose and description
- Usage instructions
- Required parameters
- Examples
- Dependencies

Read the SKILL.md to understand how to invoke the skill.

### Skill Discovery

To find available skills:

```bash
# List all skills
ls -1 team/coding-agent/skills/

# Find specific skill category
ls -1 team/coding-agent/skills/ | grep -E "^(create-|fetch-|analyze-)"

# Read skill documentation
cat team/coding-agent/skills/<skill-name>/SKILL.md
```

## Propagation

Changes to skills in the team repo are automatically propagated:

1. **Knowledge & Skills** - Auto-propagated via `team/` directory pull
2. **Ralph configuration** - Requires `just sync` + agent restart
3. **Settings** - Requires `just sync` to re-copy

## Environment Requirements

Many skills require external tools and credentials:

### JIRA Skills
- JIRA API credentials (via env vars or config)
- Project keys and component names
- Team-specific field mappings

### CI Skills
- Sippy API access
- OpenShift CI infrastructure access
- Prow job permissions
- `gh` CLI configured
- `oc` CLI configured

### SDLC Skills
- All of the above (JIRA + CI)
- Git repository access
- PR creation permissions

### Testing Skills
- Go toolchain (for mutation testing)
- Test framework dependencies

## Examples

### Create a JIRA Bug

```bash
# Use the create-bug skill
<reference team/coding-agent/skills/create-bug/SKILL.md>
<follow instructions to create properly formatted JIRA bug>
```

### Analyze a Failed Payload

```bash
# Use the analyze-payload skill
<reference team/coding-agent/skills/analyze-payload/SKILL.md>
<provide payload tag to analyze failures>
```

### Orchestrate Full SDLC

```bash
# Use SDLC orchestration skills
<reference team/coding-agent/skills/phase-design/SKILL.md>
<execute full SDLC from design through deployment>
```

## Troubleshooting

### Skill Not Found

If a skill isn't available:
1. Check `ralph.yml` has correct `skills.dirs` configuration
2. Verify skill exists: `ls team/coding-agent/skills/<skill-name>/`
3. Verify SKILL.md exists: `cat team/coding-agent/skills/<skill-name>/SKILL.md`
4. Restart Ralph after configuration changes

### Skill Execution Fails

If skill execution fails:
1. Read the SKILL.md for requirements
2. Check environment variables and credentials
3. Verify required tools are installed (`gh`, `oc`, `jq`, etc.)
4. Check script permissions: `ls -l team/coding-agent/skills/<skill-name>/scripts/`

### Missing Dependencies

Some skills depend on other skills:
- SDLC skills require JIRA and CI skills
- CI triage skills require JIRA skills for bug creation
- Review the SKILL.md for dependency information

## Best Practices

1. **Read SKILL.md First** - Always review the skill documentation before use
2. **Test in Isolation** - Test new skills in isolated environment first
3. **Check Credentials** - Verify all required credentials are configured
4. **Understand Scope** - Know which skills apply to your current context
5. **Update Regularly** - Sync with ai-helpers source for updates

## References

- [Transferred Skills Inventory](./transferred-skills.md)
- [ai-helpers Repository](https://github.com/openshift-eng/ai-helpers)
- [Team CLAUDE.md](../CLAUDE.md)
- [Team PROCESS.md](../PROCESS.md)
