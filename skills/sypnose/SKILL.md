---
name: sypnose
description: Full Sypnose protocol — session management, memory persistence, KB operations
trigger: /sypnose
---

# Sypnose Protocol

## When to Activate
- Start of any session that uses Sypnose tools
- When user types `/sypnose`
- When recovering from context loss

## Workflow

### 1. Session Start
```
memory_status          # Check Memory Palace health
kb_context limit=5     # Get HOT entries
memory_search query="last session state"  # Find previous state
```

### 2. During Work
- Save important findings: `kb_save key=<descriptive-key> content=<...> category=<cat> project=<proj>`
- Track progress: `memory_add content="Session progress: <what done, what next>"`
- Build knowledge: `memory_kg_add subject=<entity> predicate=<relation> object=<entity>`

### 3. Session End
```
memory_add content="Session summary [DATE]: [what accomplished]. Next: [what to do next]"
kb_save key=session-summary-[DATE] content="[full summary]" category=session
```

## Quality Rules
- ALWAYS save session state before ending
- ALWAYS check kb_context at start for relevant context
- Use memory_search BEFORE asking the user for info that might be stored
- Key naming: lowercase, hyphenated, descriptive (e.g., `api-auth-flow-v2`)
