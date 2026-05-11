# Agentic PR Review Checklist
**Go · go test · Ginkgo · E2E**
_Fully Agentic Workflow | Humans Approve | v1.0_

---

## Purpose & Philosophy

This checklist governs peer review of AI-generated code and tests. In a fully agentic workflow — where the AI authors both the implementation and the tests — traditional review ("does this look right to you?") is insufficient. The AI and the reviewer share the same training distribution; intuition-based review will miss whole categories of failure.

The reviewer's job shifts from reading to stress-testing. Every item below is a structural challenge, not a style preference.

> **RULE ZERO:** If you cannot describe in plain English what a test is actually testing — without looking at the implementation — that test has not passed review.

---

## Section 1 — Pre-Review Gate

Complete before opening the PR diff. If any item fails, send back without review.

### Pre-Review Gate (complete before reading a single line of diff)

- [ ] **CI is green** — All `go test` / Ginkgo suites pass. No skipped tests without a documented reason.
- [ ] **Coverage report is attached** — `go test -cover` output or equivalent is in the PR description. Reviewer verifies it exists — does not trust the number.
- [ ] **PR description explains the WHY** — AI-generated descriptions that only explain WHAT happened are insufficient. Author must add: what problem is solved, what edge cases were considered, what the AI was explicitly prompted to handle.
- [ ] **No TODO/FIXME without a linked ticket** — AI frequently leaves scaffolding. Any unresolved stub is a defect, not a note.

---

## Section 2 — Code Review (AI-Generated Implementation)

### Assumption Surfacing — Name at least 3

- [ ] **Data shape assumptions are explicit** — What struct fields does this code assume are populated? Are nil/zero values handled?
- [ ] **Ordering assumptions are documented** — Does this code assume map iteration order, goroutine scheduling order, or channel sequencing? Go maps are explicitly unordered.
- [ ] **Concurrency assumptions are correct** — Are shared resources protected? Is there a data race lurking? (Run with `-race` if not already in CI.)
- [ ] **Error assumptions are tight** — Are errors propagated, wrapped (`fmt.Errorf %w`), or swallowed? AI frequently discards errors silently.
- [ ] **External dependency assumptions are bounded** — HTTP calls, DB queries, filesystem ops — are timeouts set? Are failures handled, not panicked?

### Structural Soundness

- [ ] **Context propagation is correct** — `context.Context` flows through the call chain. No `context.Background()` buried mid-stack without justification.
- [ ] **Resource cleanup is explicit** — `defer` close/cleanup calls are present and in the right scope. AI often forgets deferred cleanup inside loops.
- [ ] **Interface contracts are honored** — If this implements an interface, does it satisfy it completely — including edge behavior, not just the happy path?
- [ ] **No magic constants** — Unexplained literals (timeouts, sizes, retry counts) must be named constants with a comment.
- [ ] **No dead code from AI scaffolding** — Unused imports, unused variables, unreachable branches. Run `go vet`. AI scaffolding frequently leaves these.

---

## Section 3 — Test Review (AI-Generated Tests)

> **The central risk of AI-generated tests:** they frequently test the implementation rather than the requirement. A test suite written by watching the code run will pass forever — even as the code drifts from intent.

### Test Independence Audit — Unit & go test (idempotency REQUIRED)

- [ ] **Each test is describable without the implementation** — Reviewer must be able to say: "This test verifies that [behavior] when [condition]." If you can't, the test is not independent.
- [ ] **Tests do not import the implementation's internal state** — Tests that reach into unexported fields or rely on side effects of prior test runs are order-dependent and fragile.
- [ ] **Test is idempotent — REQUIRED for unit tests** — Unit tests must produce the same result on every run in any order. No shared package-level state, no reliance on filesystem side effects, no `time.Now()` without injection. Non-idempotent unit tests are a **REJECT** condition.
- [ ] **Table-driven tests have adversarial cases** — AI table tests often only cover the cases the prompt described. Reviewer must add: empty input, max boundary, unexpected type, concurrent call.
- [ ] **Mocks and stubs reflect realistic failure modes** — Does the mock return errors? Does it simulate timeouts? Does it return partial results? AI mocks default to happy path.

### Ginkgo-Specific (when applicable) — idempotency REQUIRED

- [ ] **Describe/Context/It hierarchy reflects behavior, not code structure** — Ginkgo blocks should read like a spec: "When the user is unauthenticated, It should return 401." Not "When handleRequest() is called, It calls the DB."
- [ ] **BeforeEach/AfterEach are symmetric — REQUIRED** — Every setup has a corresponding teardown. Any Ginkgo spec that mutates state and lacks `AfterEach` cleanup is non-idempotent by definition and must be fixed before approval.
- [ ] **No shared mutable state in Describe scope** — Variables declared in `Describe` and mutated in `BeforeEach` are safe; variables assigned in `It` blocks that bleed to siblings are not.
- [ ] **Eventually/Consistently timeouts are justified** — AI-generated async tests often use arbitrary timeouts. Document why the timeout is set to that value.
- [ ] **No external service calls without a mock/stub** — Any Ginkgo spec that calls a real external service is an integration test, not a unit spec. It will be non-idempotent by nature of external state. Require a mock or reclassify.

---

> **E2E POLICY:** External service state bleeds between runs on this team. E2E tests are **NOT** required to be idempotent — but every non-idempotent test must document its state dependency and ordering assumptions explicitly in the test file. Undocumented non-idempotency is a **REQUEST CHANGES** condition.

### E2E Test Review — idempotency FLAG-ONLY (document, don't block)

- [ ] **Test exercises a user-visible behavior, not an internal call** — E2E tests that call internal endpoints or check internal state are integration tests mislabeled. Verify the test entry point.
- [ ] **Environment assumptions are explicit in the test file** — What external services must be in what state for this test to pass? Document it in a comment block at the top of the test. AI never does this.
- [ ] **Non-idempotency is acknowledged and documented (FLAG — not a blocker)** — If the test cannot be run twice without side effects, a comment must state: what state it leaves behind, what must be true before it runs, and whether run order matters.
- [ ] **External state bleed is bounded and named** — Which external service? Which resource (topic, queue, DB row, bucket key)? Is there a known cleanup mechanism or is this intentionally left dirty? Name it.
- [ ] **Flakiness risk is assessed** — Any test with `time.Sleep`, polling, or external HTTP is a flakiness candidate. Is there a retry strategy or is it a known risk? AI-generated E2E tests almost never include retry logic.

### The Delete Test — Run this for every test file

- [ ] **Pick 2 tests at random and mentally delete them** — Would you notice? If the answer is "probably not," those tests are not earning their keep. Flag them.
- [ ] **Verify the test can catch a real regression** — Introduce a deliberate bug (comment out a guard, flip a boolean). Does the test fail? If not, it is not testing what it claims.

---

## Section 4 — Risk Surface Coverage

Coverage percentage is a vanity metric for AI-generated tests. Assess risk surface instead.

### Risk Surface Assessment

- [ ] **Auth and permission boundaries are tested** — Is there a test for: unauthorized caller, caller with wrong role, caller with expired token?
- [ ] **Failure paths are tested, not just success** — AI defaults to testing the happy path. Count your error-return tests. They should be proportional to your error-return code.
- [ ] **Boundary values are explicit** — Off-by-one errors are the most common AI bug. Are there tests for: 0, 1, max-1, max, max+1?
- [ ] **Concurrency paths are tested (if applicable)** — If the code uses goroutines, is there a test that exercises concurrent access? AI almost never generates these.
- [ ] **Data lifecycle is tested** — Create → Read → Update → Delete. AI often tests only Create and Read. Is the full lifecycle covered?

---

## Section 5 — Review Verdict

| Verdict | Criteria |
|---|---|
| ✅ **APPROVE** | All sections complete. At least 2 adversarial test cases verified. Delete Test passed. Risk surface documented. |
| 🟡 **REQUEST CHANGES** | Any gate item failed. Any section with unchecked structural items. Delete Test not run. Risk surface gaps not acknowledged. |
| 🔴 **REJECT** | CI is red. No PR description of intent. Tests demonstrably test the implementation, not the requirement. `-race` violations present. |

---

## Section 6 — Reviewer Notes Template

Copy this block into your PR review comment:

```markdown
## Agentic Review Summary

**Assumptions surfaced:**
1. 
2. 
3. 

**Adversarial cases added or verified:**
- 

**Delete Test result:** [ ] 2 tests removed mentally — suite still caught the regression

**Risk surface gaps (acknowledged or addressed):**
- 

**Verdict:** APPROVE / REQUEST CHANGES / REJECT
```

---

## Appendix — Go-Specific Red Flags

These patterns appear frequently in AI-generated Go. Any reviewer should scan for them explicitly:

| Pattern | Risk |
|---|---|
| `err != nil` block empty | Silent error swallowing. Any blank error block must have a comment explaining why. |
| `goroutine` without WaitGroup/chan | Goroutine leak. AI launches goroutines but rarely wires up shutdown coordination. |
| `map` without mutex in goroutine | Data race. Go maps are not safe for concurrent read/write without locking. |
| `t.Parallel()` without isolation | Parallel tests that share mutable state will produce non-deterministic failures. |
| `time.Sleep` in tests | Flakiness signal. Must be replaced with `Eventually` or a channel signal. |
| `defer` inside for loop | Defers in loops run at function exit, not loop iteration. Resource leak or unexpected ordering. |
| `interface{}` / `any` as parameter | AI over-uses `any` to avoid type specificity. Demand a typed interface or concrete type. |
| `_ = err` | Explicit error discard with no comment. Needs justification or handling. |

---

_Version 1.0 | Owner: Engineering Lead | Review cadence: Monthly retrospective | Migrate to PR template after first retrospective._
