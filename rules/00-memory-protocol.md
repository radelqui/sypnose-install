# Memory Protocol — Sypnose

Your context can reset at ANY moment. Everything not in a file is LOST.

## On Start
1. Check if `.brain/task.md` exists — if yes, continue from where you left off
2. Check `.brain/session-state.md` for last known state
3. NEVER start from zero if state files exist

## While Working (every 15-20 min)
Update `.brain/task.md`:
```
## Current task: [what]
## Progress: [x] step1 [ ] step2
## Next step: [exactly what]
## Modified files: [list]
```

## On Exit
- Update `.brain/task.md` with final state
- Update `.brain/session-state.md` with timestamp + next action
- Commit and push .brain/ changes

## If Context Lost
Read .brain/ and CONTINUE. Never restart from scratch.
