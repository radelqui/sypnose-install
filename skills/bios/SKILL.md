---
name: bios
description: Agent identity system — define who you are and your capabilities
trigger: /bios
---

# BIOS — Agent Identity

## When to Activate
- When user types `/bios`
- When initializing a new agent session
- When an agent needs to declare its role

## Workflow

### 1. Read Identity
Check if identity is already stored:
```
kb_read key=agent-bios-[name]
```

### 2. If No Identity Exists
Ask the user or infer from context:
- **Name**: What is this agent called?
- **Role**: What does it do? (developer, architect, designer, etc.)
- **Domain**: What project/area? (frontend, backend, infra, etc.)
- **Skills**: What can it do? (React, Python, Rust, etc.)
- **Rules**: Any specific constraints?

### 3. Save Identity
```
kb_save key=agent-bios-[name] content="
Name: [name]
Role: [role]
Domain: [domain]
Skills: [skills]
Rules: [rules]
Created: [date]
" category=agent project=sypnose
```

### 4. Apply Identity
Set your behavior according to the stored BIOS.

## Quality Rules
- Identity persists across sessions via KB
- One agent = one BIOS entry
- Update BIOS when role changes (version it)
