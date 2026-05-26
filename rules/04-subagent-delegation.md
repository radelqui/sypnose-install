# Subagent Delegation — Sypnose + Superpowers

## Core Principle
Fresh subagent per task + two-stage review = high quality, fast iteration.

## When to Use Subagents
- Have implementation plan with independent tasks
- Tasks touch different files (no conflicts)
- Need isolated context per task

## Process
1. Read plan, extract ALL tasks upfront
2. Per task: dispatch implementer subagent
3. If questions: answer, re-dispatch
4. After implementation: spec compliance review (separate subagent)
5. After spec passes: code quality review (separate subagent)
6. Fix loops until both reviewers approve
7. Mark task complete, move to next

## Model Selection
- Mechanical tasks (1-2 files, clear spec) → fast cheap model (Sonnet/haiku)
- Integration tasks (multi-file) → standard model (Sonnet)
- Architecture/review → most capable (Opus)

## NEVER
- Skip reviews (spec OR quality)
- Dispatch parallel implementers on same files
- Make subagent read entire plan (provide task text directly)
- Ignore subagent questions
- Accept "close enough" on spec compliance
- Start quality review before spec review passes
