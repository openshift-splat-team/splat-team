# Design Document Format

## Overview

**All design documents must adhere to the OpenShift Enhancement Proposal (EP) format.** This is a mandatory process for all significant changes to OpenShift (starting with release 4.3).

## What is an OpenShift Enhancement?

An OpenShift enhancement proposal is:
- A **design document** that describes significant changes to OpenShift
- A **communication tool** for building consensus among stakeholders
- An **architectural record** for future reference
- A **mandatory requirement** for all enhancements

## Enhancement Template

Design documents use the official OpenShift enhancement template with YAML frontmatter metadata and structured markdown sections.

**Reference:** [OpenShift Enhancement Template](https://github.com/openshift/enhancements/blob/master/guidelines/enhancement_template.md)

### Required Sections

Every design document MUST include these sections:

```markdown
---
title: enhancement-title-in-kebab-case
authors:
  - "@github-username"
reviewers:
  - "@reviewer1"
  - "@reviewer2"
approvers:
  - "@approver"
api-approvers:
  - None  # Or "@api-approver" if API changes
creation-date: yyyy-mm-dd
last-updated: yyyy-mm-dd
status: provisional
tracking-link:
  - https://issues.redhat.com/browse/JIRA-KEY
---

# Enhancement Title

## Summary
Brief overview of the enhancement (2-3 sentences)

## Motivation
Why this enhancement is needed

### User Stories
Concrete examples of how users benefit

### Goals
What this enhancement achieves

### Non-Goals
What is explicitly out of scope

## Proposal

### Workflow Description
Step-by-step user workflow

### API Extensions
New or modified APIs (CRDs, fields, endpoints)

### Topology Considerations

#### Hypershift / Hosted Control Planes
HCP-specific considerations

#### Standalone Clusters
Traditional OpenShift deployment considerations

#### Single-node Deployments or MicroShift
Edge/SNO considerations

#### OpenShift Kubernetes Engine
OKE considerations (if applicable)

### Implementation Details/Notes/Constraints
Technical approach and constraints

### Risks and Mitigations
Risks and how to mitigate them

### Drawbacks
Downsides of this approach

## Alternatives (Not Implemented)
Alternative approaches considered and why they were rejected

## Open Questions [optional]
Unresolved questions

## Test Plan
Unit, integration, E2E, and scale testing strategy

## Graduation Criteria

### Dev Preview -> Tech Preview
Requirements to move from Dev Preview to Tech Preview

### Tech Preview -> GA
Requirements to move from Tech Preview to GA

### Removing a deprecated feature
Deprecation and removal strategy (if applicable)

## Upgrade / Downgrade Strategy
How upgrades and downgrades are handled

## Version Skew Strategy
Handling version differences during upgrades

## Operational Aspects of API Extensions
Operational considerations for new APIs

## Support Procedures
Diagnostic and recovery procedures for support teams

## Infrastructure Needed [optional]
Special infrastructure requirements
```

## Generating Design Documents from JIRA

When transitioning from epic planning to design (status `arch:design`), use the `generate-enhancement` skill to create a design document from the JIRA epic.

**Skill:** `coding-agent/skills/generate-enhancement/SKILL.md`

**How it works:**
1. Reads the JIRA epic content (summary, description, child issues)
2. Maps epic sections to enhancement template sections
3. Generates properly formatted markdown with frontmatter
4. Prompts for missing information
5. Writes the enhancement file to appropriate directory

**Epic sections mapped to enhancement:**

| JIRA Epic Section | Enhancement Section |
|------------------|---------------------|
| Feature Overview / Goal Summary | Summary |
| Background | Motivation |
| Goals | Goals |
| Requirements / Acceptance Criteria | Goals + Test Plan |
| Questions to Answer | Open Questions |
| Documentation Considerations | Support Procedures |

## Design Document Workflow

### 1. Epic Enters Design Phase (`arch:design`)

When a JIRA epic transitions to `arch:design`, the architect hat:

1. **Reads the epic** to understand scope and requirements
2. **Generates enhancement** using the `generate-enhancement` skill
3. **Completes missing sections** through research and analysis
4. **Adds technical depth** - architecture diagrams, API specifications, implementation approach
5. **Commits to repo** in appropriate directory (e.g., `enhancements/splat/`)

### 2. Design Review (`po:design-review` or `lead:design-review`)

The enhancement document becomes the artifact for design review:
- Reviewer reads the enhancement markdown file
- Provides feedback via comments on the epic or PR
- Approves or requests changes

### 3. Updates and Iteration

If the design is rejected:
- Architect updates the enhancement based on feedback
- Updates epic if scope changes
- Resubmits for review

## Directory Structure

Enhancement files should be organized by component or team:

```
enhancements/
├── splat/
│   ├── vmware-vcf-migration.md
│   ├── aws-dedicated-hosts.md
│   └── cloud-credential-management.md
└── ...
```

**Naming convention:** `{feature-name-in-kebab-case}.md`

## Validation Checklist

Before submitting a design document for review, verify:

- ✅ All required sections present and complete
- ✅ Frontmatter metadata complete (authors, reviewers, approvers, tracking-link)
- ✅ User stories concrete and testable
- ✅ API changes documented with examples
- ✅ Topology considerations addressed for all applicable deployment types
- ✅ Test plan includes unit, integration, E2E, and scale testing
- ✅ Graduation criteria clearly defined
- ✅ Risks identified with mitigation strategies
- ✅ Alternatives considered and documented
- ✅ No Jira wiki markup (h2., {{code}}, etc.) - use proper markdown
- ✅ Consistent terminology throughout

## Best Practices

1. **Generate from JIRA early** - Use the `generate-enhancement` skill as soon as epic content is mature
2. **Start with structure** - Fill in all sections, use TODO markers for incomplete areas
3. **Add technical depth** - Include architecture diagrams, sequence diagrams, API examples
4. **Be specific** - Concrete examples better than abstract descriptions
5. **Consider all topologies** - Address HCP, standalone, SNO even if "not applicable"
6. **Document tradeoffs** - Explain why chosen approach is better than alternatives
7. **Keep JIRA updated** - Epic should remain source of truth for requirements
8. **Iterate with stakeholders** - Share draft early, incorporate feedback continuously

## Common Pitfalls

**Avoid:**
- ❌ Skipping "Non-Goals" section - leads to scope creep
- ❌ Vague user stories - "As a user, I want better performance"
- ❌ Missing API examples - describing APIs without showing concrete YAML/JSON
- ❌ Ignoring topology differences - assuming all deployments are the same
- ❌ Weak test plan - "We'll add tests" without specifics
- ❌ Unrealistic graduation criteria - criteria that can't be objectively verified
- ❌ Forgetting upgrade strategy - how existing clusters migrate to new version
- ❌ No support procedures - leaving support teams without diagnostic guidance

## References

- **Enhancement Process**: https://github.com/openshift/enhancements
- **Enhancement Template**: https://github.com/openshift/enhancements/blob/master/guidelines/enhancement_template.md
- **Enhancement Guidelines**: https://github.com/openshift/enhancements/tree/master/guidelines
- **Generate Enhancement Skill**: `coding-agent/skills/generate-enhancement/SKILL.md`

## Status Transitions

Design documents are created and reviewed as part of the epic lifecycle:

| Status | Design Document State |
|--------|----------------------|
| `arch:design` | Creating/writing enhancement |
| `lead:design-review` | Enhancement awaiting lead review |
| `po:design-review` | Enhancement awaiting human review |
| `arch:plan` | Enhancement approved, creating story breakdown |

The enhancement file serves as the primary artifact for design review gates.
