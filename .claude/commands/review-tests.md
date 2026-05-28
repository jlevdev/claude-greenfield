You are entering **CHAOS MONKEY mode** for test-suite validation.

> **Goal:** Verify that tests for items currently in `review` are robust enough to catch regressions.

## Hard boundaries — read before doing anything

**IN BOUNDS:**
- Source files directly relevant to tickets in `tickets/features/review/` and `tickets/remediation/review/`

**OUT OF BOUNDS — never touch these:**
- OS files, system configs, package manager files
- CI/CD configuration (`.github/`, `.gitlab-ci.yml`, etc.)
- Environment files (`.env`, `.env.local`, etc.)
- Any code entirely unrelated to the features under review
- Node modules, build artifacts, lock files

**No changes are committed.** Every mutation must be reverted before this session ends. If anything goes wrong and you can't revert cleanly, stop and report to the user immediately.

## Process

### 1. Baseline
- Read all tickets in `tickets/features/review/` and `tickets/remediation/review/` to understand what was implemented and which files were touched.
- Run the full test suite. If tests are already failing, **stop here** and report the failures — do not proceed with mutations until the baseline is green.

### 2. Mutate and observe
For each relevant code path, apply one mutation at a time:
- Flip a boolean or comparison operator (`===` → `!==`, `>` → `<`)
- Off-by-one on a loop bound, index, or count
- Remove a guard clause, null check, or early return
- Return a wrong value (empty array, `null`, `0`, wrong type)
- Skip a side effect (comment out a function call)
- Swap two similar values or arguments

After each mutation:
1. Run only the tests relevant to the mutated code.
2. Record the result.
3. **Revert the mutation immediately.**

### 3. Record findings
Write results to `tickets/test-review-YYYY-MM-DD.md`:

```markdown
# Test Review — YYYY-MM-DD

## Tickets in Scope
- feat-N: [title]
- rem-N: [title]

## Summary
X mutations applied. Y caught by tests (✅). Z not caught (❌).

## Coverage Gaps
| File | Approx. line | Mutation applied | Test that should have caught it | Result |
|------|-------------|-----------------|-------------------------------|--------|
| src/foo.ts | ~42 | flipped `===` to `!==` in credential check | login rejects invalid password | ❌ passed |

## Recommendations
- [ ] Add test: [describe the missing scenario precisely]
- [ ] Add test: ...

## Mutations That Were Caught ✅
(brief list — confirms what coverage is working)
```

### 4. Verify clean state
After all mutations, run the full test suite one final time to confirm everything is green and all mutations were reverted.

If no gaps are found, note that explicitly — it is a good result worth recording.
