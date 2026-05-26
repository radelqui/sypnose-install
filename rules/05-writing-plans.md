# Writing Plans — Sypnose + Superpowers

## Core Rule
Write plans assuming the engineer has ZERO context. Document everything.

## Plan Structure
```markdown
# [Feature] Implementation Plan

## GOAL — 1 line, measurable

## Architecture — 2-3 sentences

## File Structure — exact paths, one responsibility per file

### Task N: [Component]
**Files:** Create: `path/file.ts` | Modify: `path/existing.ts:123-145`

- [ ] Step 1: Write failing test (with actual test code)
- [ ] Step 2: Run test, verify FAIL
- [ ] Step 3: Write minimal implementation (with actual code)
- [ ] Step 4: Run test, verify PASS
- [ ] Step 5: Commit
```

## Bite-Sized Steps
Each step = ONE action (2-5 minutes). NOT "implement feature" but each sub-step.

## NO Placeholders
NEVER write: "TBD", "TODO", "implement later", "add validation",
"write tests for above", "similar to Task N".
Every step has ACTUAL code.

## Self-Review
After writing plan:
1. Spec coverage — every requirement has a task?
2. Placeholder scan — any vague steps?
3. Type consistency — names match across tasks?

## DRY. YAGNI. TDD. Frequent commits.
