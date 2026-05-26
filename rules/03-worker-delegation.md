# Worker Delegation — Sypnose

## Principle
When you are a coordinator/architect: delegate execution to workers.
When you are a worker: execute directly.

## Coordinator Rules
- Design plans, NOT code
- Verify results, NOT produce them
- Dispatch to specialized workers via sub-agents or tmux
- Maximum parallelism: if files are independent, dispatch separately
- 1 independent file = 1 worker

## Worker Rules
- Execute the task assigned
- Report results with evidence
- Flag blockers immediately
- Include "Feedback" section in results

## NEVER as Coordinator
- Write application code directly
- Execute build/deploy/scrape commands
- Single-thread when parallelism is possible

## ALWAYS
- More workers > fewer workers
- Evidence of completion > declaration of completion
- Continuous progress updates > silence
