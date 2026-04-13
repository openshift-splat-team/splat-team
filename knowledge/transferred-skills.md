# Transferred Skills from ai-helpers

This document catalogs the skills and agents transferred from `/home/rvanderp/code/ai-helpers` to this team repo on 2026-04-13.

## Overview

**Total Skills Transferred:** 74  
**Total Agents Transferred:** 2  
**Source Repository:** openshift-eng/ai-helpers

These skills provide comprehensive automation and assistance for OpenShift development workflows, including JIRA management, CI/CD operations, SDLC orchestration, and more.

## Skill Categories

### JIRA Skills (18 skills)

Issue management and workflow automation for JIRA:

- `categorize-activity-type` - Categorize JIRA tickets into activity types using AI
- `cntrlplane` - Jira conventions for the CNTRLPLANE project
- `create-bug` - Implementation guide for creating well-formed JIRA bugs
- `create-epic` - Implementation guide for creating Jira epics
- `create-feature` - Implementation guide for creating Jira features
- `create-feature-request` - Implementation guide for creating Feature Requests
- `create-release-note` - Generate bug fix release notes from Jira tickets
- `create-story` - Implementation guide for creating well-formed JIRA stories
- `create-task` - Implementation guide for creating Jira tasks
- `extract-prs` - Recursively extract GitHub Pull Request links from JIRA issues
- `gcp-hcp` - GCP HCP team-specific Jira requirements
- `generate-enhancement` - Generate OpenShift enhancement proposal markdown from Jira
- `hypershift` - HyperShift team-specific Jira requirements
- `jira-doc-generator` - Generate comprehensive documentation from Jira features
- `jira-issues-by-component` - Secure curl wrapper for listing JIRA issues by component
- `jira-validate-blockers` - Validate proposed release blockers
- `ocpbugs` - Jira conventions and bug templates for the OCPBUGS project
- `status-analysis` - Shared engine for analyzing Jira issue activity

### CI Skills (26 skills)

OpenShift CI, Prow jobs, and payload analysis:

- `analyze-payload` - Analyze payloads (rejected, accepted, or in-progress)
- `fetch-jira-issue` - Fetch JIRA issue details including status and assignee
- `fetch-job-run-summary` - Fetch Prow job run summary from Sippy
- `fetch-new-prs-in-payload` - Fetch pull requests new in a given payload
- `fetch-payloads` - Fetch recent release payloads from OpenShift release controller
- `fetch-prowjob-json` - Fetch key data from a Prow job's prowjob.json
- `fetch-regression-details` - Fetch detailed Component Readiness regression info
- `fetch-related-triages` - Fetch existing triages and untriaged regressions
- `fetch-releases` - Fetch available OpenShift releases from Sippy
- `fetch-test-report` - Fetch OpenShift CI test report by name
- `fetch-test-runs` - Fetch test runs from Sippy API including outputs
- `oc-auth` - Helper skill to retrieve OAuth tokens from OpenShift clusters
- `payload-autodl-json` - Schema for autodl JSON data file
- `payload-experimental-reverts` - Experimental testing of medium-confidence reverts
- `payload-results-yaml` - State management for agentic payload triage
- `prow-job-analyze-install-failure` - Analyze OpenShift installation failures
- `prow-job-analyze-metal-install-failure` - Analyze bare metal install failures
- `prow-job-analyze-resource` - Analyze Kubernetes resource lifecycle in Prow
- `prow-job-analyze-test-failure` - Analyze failed Prow CI tests
- `prow-job-artifact-search` - Search, list, and fetch artifacts from Prow CI jobs
- `prow-job-extract-must-gather` - Extract and decompress must-gather archives
- `revert-pr` - Git revert workflow and Revertomatic PR template
- `set-release-blocker` - Set the Release Blocker field on a JIRA issue
- `stage-payload-reverts` - Create TRT JIRA bugs, open revert PRs, trigger jobs
- `triage-regression` - Create or update Component Readiness triage document
- `trigger-payload-job` - Trigger payload testing jobs (MUST be used for payload jobs)

### SDLC Skills (8 skills)

Software Development Lifecycle orchestration:

- `phase-completion` - Update Jira, verify deployment, generate completion report
- `phase-design` - Create detailed implementation specification from Jira
- `phase-enhancement` - Generate OpenShift enhancement proposal from Jira
- `phase-implementation` - Execute code changes according to implementation plan
- `phase-merge` - Monitor PR merge and track deployment to payload
- `phase-pr-review` - Create pull request with comprehensive description
- `phase-testing` - Run comprehensive test suite and validate coverage
- `sdlc-state-yaml` - State management for SDLC orchestrator (required)

### Teams Skills (15 skills)

Team structure knowledge and health analysis:

- `analyze-regressions` - Analyze regression data for OpenShift releases
- `coderabbit-adoption` - Report on CodeRabbit adoption across OCP payload repos
- `coderabbit-inheritance-scanner-check` - Check for CodeRabbit inheritance
- `coderabbit-inheritance-scanner-existing-pr` - Handle existing PRs for inheritance
- `coderabbit-inheritance-scanner-open-pr` - Open PRs for missing inheritance
- `coderabbit-inheritance-scanner-search` - Search for missing inheritance
- `coderabbit-rules-from-pr-reviews` - Propose CodeRabbit rules from PR reviews
- `find-repo-owner` - Find repository owners and approvers
- `health-check-jiras` - Query and summarize JIRA bugs by component
- `health-check-regressions` - Query and summarize regression data
- `health-check` - Analyze and grade component health
- `list-components` - List all OCPBUGS components, optionally by team
- `list-jiras` - Query and list raw JIRA bug data
- `list-regressions` - Fetch and list raw regression data
- `list-repos` - Report on repository purpose and approvers

### Code Review Skills (2 skills)

Automated code quality review:

- `pr-review` - Automated PR code quality review with language-aware analysis
- `pre-commit-review` - Pre-commit code quality review with language analysis

### Testing Skills (2 skills)

Comprehensive testing utilities:

- `mutation-test` - Test operator controller quality through mutation testing
- `test-structure-only` - Analyze test code structure without running tests

### OpenShift Skills (2 skills)

OpenShift development utilities:

- `cluster-health` - Comprehensive health check on OpenShift cluster
- `om-bootstrap` - Bootstrap OpenShift Manager (OM) integration

### Git Skills (1 skill)

Git workflow automation:

- `debt-scan` - Analyze technical debt indicators in the repository

## Agents

### feedback.md

General feedback agent for collecting and processing user feedback.

**Location:** `coding-agent/agents/feedback.md`

### step-registry-analyzer.md

CI-specific agent for understanding and listing OpenShift CI components including workflows, chains, and refs in hierarchical structure.

**Location:** `coding-agent/agents/step-registry-analyzer.md`

## Usage

Skills are automatically available via Ralph's `skills.dirs` configuration. To use a skill:

```bash
# Example: Use JIRA skill to create a bug
<use jira:create-bug skill>

# Example: Use CI skill to analyze a payload
<use ci:analyze-payload skill>

# Example: Use SDLC orchestrator
<use sdlc:orchestrate skill>
```

## Integration Notes

### Ralph Configuration

Skills are loaded via `ralph.yml` configuration:

```yaml
skills:
  dirs:
    - team/coding-agent/skills
    - team/projects/<project>/coding-agent/skills  # If project-specific
    - team/members/superman/coding-agent/skills    # If member-specific
```

### Agent Configuration

Agents are symlinked from:
- `team/coding-agent/agents/` → `.claude/agents/` (team-level)
- `team/projects/<project>/coding-agent/agents/` (project-specific)
- `team/members/superman/coding-agent/agents/` (member-specific)

## Knowledge Dependencies

Many of these skills depend on domain knowledge that may also need to be transferred:

1. **JIRA conventions** - Team-specific field mappings, status workflows, and templates
2. **CI infrastructure** - Sippy API endpoints, Prow job patterns, payload workflows
3. **OpenShift processes** - Enhancement workflows, release processes, component ownership

Consider creating corresponding knowledge files in `knowledge/` or `projects/<project>/knowledge/` as needed.

## Maintenance

**Source:** `/home/rvanderp/code/ai-helpers`  
**Last Updated:** 2026-04-13  
**Transfer Method:** Direct copy from ai-helpers plugin skills directories

To update these skills in the future:
1. Pull latest changes from ai-helpers repository
2. Use selective copy to update specific skill categories
3. Test skills in isolated environment before deploying to team
4. Update this documentation with changes

## References

- [ai-helpers repository](https://github.com/openshift-eng/ai-helpers)
- [ai-helpers plugins documentation](https://openshift-eng.github.io/ai-helpers/)
- [ai-helpers PLUGINS.md](/home/rvanderp/code/ai-helpers/PLUGINS.md)
