---
name: graphify
description: Transform any input into knowledge graph entries
trigger: /graphify
---

# Graphify — Knowledge Graph Builder

## When to Activate
- When user types `/graphify`
- When processing documents, conversations, or data that should become structured knowledge

## Workflow

### 1. Analyze Input
Take the provided content and identify:
- **Entities**: People, systems, concepts, files, services
- **Relations**: connects_to, depends_on, owns, created_by, part_of, uses, etc.
- **Facts**: Concrete statements about entities

### 2. Extract Triples
For each fact, create a triple: `(subject, predicate, object)`

Examples:
- (GestoriaRD, uses, PostgreSQL)
- (FacturaIA, depends_on, Supabase)
- (Carlos, owns, Sypnose)
- (server-67, hosts, sypnose-unified-mcp)

### 3. Ingest to Knowledge Graph
```
memory_kg_add subject="GestoriaRD" predicate="uses" object="PostgreSQL"
memory_kg_add subject="FacturaIA" predicate="depends_on" object="Supabase"
```

### 4. Optionally Deep-Ingest Full Text
```
deep_ingest content="[full text]" source="[origin description]"
```

### 5. Report
List all triples created and confirm ingestion.

## Quality Rules
- Minimum 5 triples per graphify invocation
- Use consistent entity names (check existing with `memory_kg_query`)
- Predicates should be lowercase, snake_case
- After ingestion, verify with `memory_kg_query query="[entity]"`
