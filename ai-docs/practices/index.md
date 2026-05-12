# Engineering Practices

Engineering standards and practices for the Splat Team.

---

## Contents

- **[coding-standards.md](coding-standards.md)** - Code conventions and style (coming soon)
- **[testing.md](testing.md)** - Test strategy and requirements (coming soon)
- **[ci-cd.md](ci-cd.md)** - Prow and GitHub Actions usage (coming soon)

---

## Quick References

**Go Style:**
- Follow [Effective Go](https://golang.org/doc/effective_go.html)
- Follow [OpenShift coding conventions](https://github.com/openshift/openshift-docs/blob/main/contributing_to_docs/doc_guidelines.adoc)

**Testing:**
- Unit tests required for all new code
- vSphere e2e tests required for platform features
- Test coverage target: >70%

**CI:**
- All PRs must pass Prow presubmits
- vSphere e2e tests run on multiple vSphere versions (7.0, 8.0)

---

**See Also:**
- [OpenShift Contributor Guide](https://github.com/openshift/community/blob/master/CONTRIBUTING.md)
- [Kubernetes Code Conventions](https://github.com/kubernetes/community/blob/master/contributors/guide/coding-conventions.md)
