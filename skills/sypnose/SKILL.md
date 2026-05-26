---
name: sypnose
description: >
  Comando UNICO del Service Manager Sypnose para investigar, planificar, despachar y verificar.
  v3.0 integra: Boris Cherny 2026 (/goal, Agent Teams, /batch, delegation philosophy),
  Karpathy 4 principios (think, simplicity, surgical, goal-driven), estado del arte
  (Planner-Coder Gap fix, Multi-Tier Verification, Context Engineering, Spec-Driven Development),
  mas 10 Iron Laws Sypnose, 6 trampas operativas, y workers claw-dispatch con GOALs.
  UN comando. Sin excepciones. Si no pasaste por aqui, el trabajo no se envio bien.
trigger: crear plan, enviar trabajo, despachar agente, plan para, prompt para, wave, dispatch, sypnose
version: 3.0.0
author: Carlos De La Torre + SM
date: 2026-05-19
user-invocable: true
---

# /sypnose v3 — Comando Unificado del Service Manager

> **Fuentes**: Boris Cherny 2026, Karpathy 4 Principles, Anthropic /ultraplan + /goal + Agent Teams,
> GSD pipeline, Superpowers Iron Laws, arXiv Planner-Coder Gap (2510.10460).
> **Adaptado a**: Sypnose (agentes tmux remotos SSH, Boris MCP, KB Hub, Memory Palace, claw-dispatch workers).

## FILOSOFIA

```
LEER → PLANIFICAR → APROBAR → DESPACHAR → VERIFICAR → RECUPERAR/GUARDAR
         ↑                                    ↓ (si falla)
         └────────── ROLLBACK ───────────────┘
```

Cada paso tiene PUERTA. Si no pasa, no avanza. Si VERIFICAR falla, ROLLBACK a PLANIFICAR.

**Karpathy #4 — Goal-Driven**: Cada wave, cada worker tiene un GOAL explicito.
Si no cabe en 1 linea, divide mas.

**Boris — Delegation**: Trata al agente como ingeniero delegado, NO como pair programmer.
Provee goal, constraints, y acceptance criteria upfront.

## FASE 1 — LEER

1. `boris_start_task` o escribir `.brain/task.md`
2. Estado de TODOS los agentes (capture-pane)
3. Contexto: `kb_search` + `memory_search` + `graphify query`
4. NO DUPLICAR — si alguien ya hizo esto, PARAR

## FASE 2 — PLANIFICAR

Estructura canonica del prompt:
```
═══ EMISOR ═══ FROM: <agente> / TO: <agente> / KEY: <kb-key>

# [TITULO]
## GOAL — 1 linea medible y falsable
## CONTEXTO — KBs, commits, trabajo previo
## WAVES — tareas CONCRETAS con archivos exactos
## VERIFICACION — criterio medible por wave
## MEJORA CONTINUA — 3 dimensiones feedback
## §11 LEY DEL ARQUITECTO — "si algo no encuadra, MEJORALO"

═══ FIRMA ═══ <agente> / <YYMMDD>
```

Validaciones: FIRMA, MEJORA, §11, GRAPHIFY, VERIFICACION, CONCRETO, NO-DUPLICAR, GOAL.

## FASE 3 — APROBAR

Carlos dice OK o pide cambios. Sin OK = no se envia.

## FASE 4 — DESPACHAR

| Tamano | Metodo |
|---|---|
| < 500 chars | send-keys directo |
| > 500 chars | Escribir /tmp/archivo, enviar pointer |

Confirmar recepcion (15 seg despues). Paralelizar otros agentes idle.

### Workers claw-dispatch

```json
{
  "description": "Wave 1",
  "workspace": "/path",
  "max_parallel": 8,
  "tasks": [{
    "id": "UUID",
    "profile": "researcher|executor|verifier|planner",
    "model": "openai/gemini-2.5-pro",
    "description": "CONCRETA — archivo, endpoint, formato output",
    "goal": "1 linea medible"
  }]
}
```

Modelos: `openai/gemini-2.5-pro` (workers), `openai/gemini-2.5-flash` (verifiers).

## FASE 5 — VERIFICAR (Multi-Tier)

1. **Tier 1**: Build/test determinista (agente ejecuta)
2. **Tier 2**: SM verifica INDEPENDIENTE via SSH
3. **Tier 3**: `boris_verify` con output real

Si falla → ROLLBACK: revert + log KB + diagnosticar + re-planificar.

## FASE 6 — GUARDAR

```
kb_save key=resultado-<tema>-<YYMMDD>
memory_add content="sesion: que se logro"
boris_save_state progress="..." next_step="..."
```

## 13 REGLAS DE HIERRO

1. Sin boris_start_task no hay tarea
2. Sin OK Carlos no se envia
3. Sin verificacion no hay resultado
4. Sin §11 el agente ejecuta ciego
5. Sin MEJORA CONTINUA el SM no aprende
6. Sin capture-pane no se despacha
7. NUNCA 2 prompts al mismo agente mientras trabaja
8. NUNCA dejar agentes idle si hay trabajo
9. Plan antes de codigo (Boris)
10. GOAL por wave (Karpathy)
11. Surgical changes (Karpathy)
12. Archivos DISTINTOS por tarea
13. Verificacion entre waves
