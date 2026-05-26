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

> **Fuentes**: Boris Cherny 2026 (howborisusesclaudecode.com), Karpathy 4 Principles,
> Anthropic /ultraplan + /goal + Agent Teams + /batch, GSD pipeline, Superpowers Iron Laws,
> arXiv Planner-Coder Gap (2510.10460), Multi-Tier Verification, Context Engineering.
> **Adaptado a**: Sypnose (agentes tmux remotos SSH, Boris MCP, KB Hub, Memory Palace, claw-dispatch workers).

---

## FILOSOFIA

```
LEER → PLANIFICAR → APROBAR → DESPACHAR → VERIFICAR → RECUPERAR/GUARDAR
         ↑                                    ↓ (si falla)
         └────────── ROLLBACK ───────────────┘
```

Cada paso tiene PUERTA. Si no pasa, no avanza. Si VERIFICAR falla, ROLLBACK a PLANIFICAR.
Esto no es burocracia — Boris, GSD, Superpowers y 3 meses Sypnose lo confirman independientemente.

**Principio Karpathy #4 — Goal-Driven**: Cada wave, cada worker, cada dispatch tiene un GOAL explicito.
Si no puedes escribir el goal en 1 linea, no entiendes la tarea. Divide mas.

**Principio Boris — Delegation**: Trata al agente como ingeniero delegado, NO como pair programmer.
Provee goal, constraints, y acceptance criteria upfront. Lanza y vuelve cuando termine.
Menos interrupciones = corridas mas autonomas = mayor calidad.

---

## FASE 1 — LEER (antes de pensar siquiera)

> "Think Before Coding — don't assume; state assumptions explicitly." — Karpathy #1
> "Map codebase before planning." — GSD

### 1.1 Boris registra la tarea

```
boris_start_task:
  task_description: "[1 linea: que + para quien + por que]"
  verification_plan: "[como verificar: curl/SELECT/build/screenshot]"
```

Fallback si MCP caido: escribir `.brain/task.md` manualmente.

**PUERTA 1**: Sin boris_start_task o task.md = tarea invisible. No continuar.

### 1.2 Estado de TODOS los agentes

```bash
for s in FacturaIA gestion-contadoresrd dgii seguridad-server; do
  echo "=== $s ==="
  /usr/bin/tmux capture-pane -t "$s" -p 2>/dev/null | tail -15
done
```

| Estado | Senal | Accion SM |
|---|---|---|
| IDLE | Cursor `>` vacio | Disponible para despacho |
| WORKING | Spinner ("Cogitating"...) | NO TOCAR. Esperar. |
| BLOCKED | "How is Claude doing? 0: Dismiss" | Enviar `0 Enter` inmediato |
| QUESTION | Pregunta abierta al final | Responder, luego despachar |
| DONE | "Worked for Xm Ys" | Leer resultados → FASE 5 |

Transiciones validas: IDLE→WORKING, WORKING→DONE/BLOCKED/QUESTION, BLOCKED→IDLE, QUESTION→WORKING, DONE→IDLE.

**PUERTA 2**: Si agente destino WORKING → no enviar nada. Punto.

### 1.3 Leer contexto (3 fuentes en PARALELO, 30 seg max)

**A) Trabajo previo del agente:**
```bash
cd /home/gestoria/builds/<repo> && git log --oneline -10 main
```

**B) Knowledge Hub + Memory Palace:**
```
kb_search query="<tema>" limit=5
sypnose_search query="<tema>" limit=3
```

**C) Graphify o Glob+Grep fallback:**
```bash
graphify query "donde se usa <componente>?" --graph <ruta>
```
Si Graphify no devuelve nada: `Glob + Grep` como fallback. Declarar: "Graphify sin resultados. Fallback: Glob `**/<pattern>` encontro N archivos."

**D) NO DUPLICAR:**
Si evidencia muestra que alguien ya hizo esto → **PARAR**. Citar: "KB XXXX ya tiene esto."

**PUERTA 3**: Sin evidencia de lectura = plan ciego. No continuar.

---

## FASE 2 — PLANIFICAR (el prompt ES el plan)

> "Pour your energy into the plan so Claude can 1-shot the implementation." — Boris Cherny
> "Simplicity First — write minimum code that solves the problem." — Karpathy #2

### 2.1 Estructura canonica del prompt

```
═══ EMISOR ═══ FROM: sm-claude-<cli|desktop|web> / TO: <agente> / KEY: <kb-key-o-hito>

# [TITULO — 1 linea]

## GOAL
[1 linea: que debe ser verdad cuando esta tarea termine. Medible. Falsable.]

## CONTEXTO
De donde viene. Que ya existe. Que falta. KBs: [ids]. Commits: [hashes].

## RECIBIDO
[Reconocer trabajo previo del agente. Omitir si no hay.]

## PREGUNTAS ABIERTAS — RESPUESTAS
[Contestar TODAS las preguntas que el agente dejo. Omitir si no hay.]

## GRAPHIFY — DEPENDENCIAS
[Output real de graphify o declaracion de fallback.]

## WAVE 1 — [nombre descriptivo]
### GOAL W1: [que debe ser verdad al terminar wave 1]
### Tarea 1.1: [CONCRETA — archivo, endpoint, tabla, linea]
### Tarea 1.2: [CONCRETA — archivo DISTINTO, race-free]

### VERIFICACION W1 (gate obligatorio)
- [ ] [criterio medible: `curl -s url | jq .status` == "ok"]
- [ ] [criterio medible: `SELECT COUNT(*) FROM tabla` > N]

## WAVE 2 — [nombre] (depende de W1 verificado)
### GOAL W2: [que debe ser verdad al terminar wave 2]
[Solo si hay dependencia real.]

## CRITERIOS DE EXITO FINALES
- [ ] [Build: `npm run build` -> 0 errors]
- [ ] [API: `curl -sf url` -> 200]
- [ ] [BD: query -> resultado esperado]

## MEJORA CONTINUA — Feedback al SM (3 dimensiones)

### D1 — Sistema/Repo
Que del prompt NO encajaba con tu realidad tecnica?

### D2 — Prompt/Comunicacion
Que fue ambiguo, contradictorio, redundante?

### D3 — Flujo/Proceso
Que del SM->Wave->Verify no funciono o se puede acelerar?

Si todo encajo: "0 hallazgos en esta dimension".

## ENTREGA
- git add + commit + push
- kb_save key=resultado-<key>-<YYMMDD>
- Incluir Feedback al SM en el KB

## §11 LEY DEL ARQUITECTO
Tu conoces tu sistema mejor que el SM. Si algo en este prompt no
encuadra con tu realidad, OMITELO o MEJORALO. Reporta que cambiaste y por que.

═══ FIRMA ═══ sm-claude-<cli|desktop|web> / <YYMMDD>
```

### 2.2 Validaciones (skill RECHAZA si falta)

| # | Check | Busca | Error |
|---|---|---|---|
| V1 | FIRMA | `═══ EMISOR ═══` + `═══ FIRMA ═══` | "Falta §4.0" |
| V2 | MEJORA | 3 dimensiones feedback | "Falta §4.1" |
| V3 | §11 | "OMITELO o MEJORALO" | "Falta §11" |
| V4 | GRAPHIFY | Output real o fallback declarado | "Falta dependencias" |
| V5 | VERIFICACION | Min 1 criterio medible por wave | "Falta gate entre waves" |
| V6 | CONCRETO | Archivo/endpoint/tabla por tarea | "Tarea vaga" |
| V7 | NO DUPLICAR | Evidencia FASE 1 | "Sin lectura previa" |
| V8 | GOAL | `## GOAL` global + `### GOAL W` por wave | "Sin goal — divide mas" |

**PUERTA 4**: Validacion falla → corregir y re-validar. No pasar a FASE 3.

### 2.3 Anti-Planner-Coder Gap

> 75.3% de fallos en sistemas multi-agente vienen de informacion perdida entre
> quien planifica y quien ejecuta. — arXiv 2510.10460

Para cerrar el gap:
1. **Cada tarea lleva su contexto** — NO depender de "el agente ya sabe"
2. **Archivos CONCRETOS** con path completo, no "el componente de contactos"
3. **Output esperado EXPLICITO** — "Genera JSON con {hook, endpoint, fields[]}"
4. **Si hay ambiguedad, resolver en el prompt** — no dejar al agente que adivine

### 2.4 Reglas del prompt (Iron Laws)

1. **Cada tarea autocontenida** — ejecutable sin leer otra wave
2. **Archivos DISTINTOS por tarea** — nunca 2 tareas en el mismo archivo
3. **Verificacion entre waves** — NUNCA Wave N+1 sin confirmar Wave N
4. **Descripcion CONCRETA** — archivo, linea, endpoint, tabla
5. **GOAL por wave** — 1 linea, medible, falsable
6. **Simplicity First** — el agente arregla SOLO lo pedido, no mejora codigo adyacente
7. **Surgical Changes** — un commit por unidad logica de trabajo

---

## FASE 3 — APROBAR (Carlos decide)

Presentar a Carlos:
- GOAL de la tarea (1 linea)
- A que agente va
- Agentes idle (proponer paralelo)

Carlos: "dale"/"ok"/"si" → FASE 4. Cambios → corregir. "no" → descartar.

**PUERTA 5**: Sin OK explicito = no se envia.

**Timeout**: Si Carlos no responde en 30 min y la tarea es rutinaria (no afecta prod, no toca datos reales) → recordar 1 vez. Si critica (deploy, BD, DGII) → esperar indefinidamente.

---

## FASE 4 — DESPACHAR

### 4.1 Metodo de envio

| Tamano | Metodo |
|---|---|
| < 500 chars | `send-keys` directo |
| > 500 chars | Escribir `/tmp/sm-prompt-<agente>.txt`, enviar pointer |
| Si falla | `load-buffer` + `paste-buffer` (bypass hook) |

Siempre usar `/usr/bin/tmux` (ruta absoluta — bypass boris-protect).

**NUNCA send-keys multi-linea** — cada `\n` es Enter = desastre.

### 4.2 Confirmar recepcion (15 seg despues)

```bash
/usr/bin/tmux capture-pane -t <SESSION> -pS -10
```
- Spinner = RECIBIDO
- Sin spinner = NO recibio. Reintentar con Enter.
- Rating prompt = `0 Enter`, luego reintentar.

**Retry**: Max 3 intentos. Si falla 3 veces → reportar a Carlos, no insistir.

**PUERTA 6**: Sin confirmacion recepcion = no contar como enviado.

### 4.3 Paralelizar INMEDIATAMENTE

Mientras agente A trabaja:
1. Scan agentes B, C, D
2. Cada IDLE → FASE 1 con OTRA tarea independiente
3. **NUNCA agentes idle si hay trabajo**
4. **NUNCA 2 agentes en el mismo archivo**

### 4.4 Squad Mode (cuando Carlos dice "prisas/rapido/Squad")

Cada agente Opus puede lanzar 8 sub-agents Sonnet en paralelo:
- Incluir en prompt: "Usa sub-agents Task. Min 6 sub-tasks simultaneos."
- Cada sub-task en archivo DISTINTO
- Sub-agents: Sonnet 4.6 (NUNCA Opus)
- El Opus coordina, los Sonnet ejecutan

---

## FASE 4B — WORKERS CLAW-DISPATCH

> "Mil workers > un SM. Si dudas, mas workers." — Sypnose v6

### Cuando workers vs agentes tmux

| Criterio | Agente tmux | Workers |
|---|---|---|
| Editar archivos, builds, deploys | SI | NO (Gemini no ejecuta bash multi-step) |
| Investigar, analizar, clasificar | Desperdicia agente | SI |
| 1-4 tareas independientes | SI | Overkill |
| 5-50 tareas repetitivas | Solo hay 4 agentes | SI |
| Leer 20 archivos y sintetizar | Consume contexto | SI (1 worker/archivo) |

### Dispatch JSON con GOALs

```json
{
  "description": "Wave 1 — [descripcion]",
  "workspace": "/home/gestoria/builds/<repo>",
  "keep_workspace": true,
  "max_parallel": 8,
  "tasks": [
    {
      "id": "<uuid>",
      "profile": "researcher",
      "model": "openai/gemini-2.5-pro",
      "timeout_secs": 300,
      "depends_on": [],
      "description": "[QUE leer, QUE producir, formato output EXPLICITO]",
      "goal": "[1 linea medible — que debe ser verdad cuando termine]"
    },
    {
      "id": "<uuid-verifier>",
      "profile": "verifier",
      "model": "openai/gemini-2.5-flash",
      "timeout_secs": 120,
      "depends_on": ["<uuid-prev-1>", "<uuid-prev-2>"],
      "description": "[Consolidar + validar outputs previos. Listar gaps.]",
      "goal": "[Gap report o catalogo unificado]"
    }
  ]
}
```

### Reglas dispatch

1. **GOAL obligatorio** por task — 1 linea, medible
2. **UUIDs reales** — `cat /proc/sys/kernel/random/uuid`
3. **Workspace existe** — `mkdir -p` antes
4. **Verificador entre waves** — verifier depende de Wave N, Wave N+1 depende de verifier
5. **Descripcion CONCRETA** — archivo exacto, formato output
6. **max_parallel maximal** — 8 tasks independientes = max_parallel 8
7. **Output schema EXPLICITO** — "Output: JSON con {field1, field2}" o "Output: Markdown tabla con..."

### Modelos workers (Mayo 2026)

| Profile | Modelo | Para | NO para |
|---|---|---|---|
| researcher | `openai/gemini-2.5-pro` | Leer, analizar, sintetizar | Editar, builds |
| planner | `openai/gemini-2.5-pro` | Sub-planes, arquitectura | Bash |
| verifier | `openai/gemini-2.5-flash` | Validar, comparar | Nada pesado |
| executor | `openai/gemini-2.5-pro` | curl simple, health check | Multi-step bash |

**PROHIBIDO**: `cerebras-qwen3-235b` (cuelga), `claude-sonnet-4-6` (falta token), `gemini-2.5-flash` sin prefix `openai/`.

### Enviar dispatch

```bash
ssh-217 exec: "curl -s -X POST http://localhost:18830/dispatch \
  -H 'Content-Type: application/json' -d '[JSON]'"
# Fallback: puerto 18810
```

### Leer resultados

```bash
ssh-217 exec: "curl -s http://localhost:18830/status/<plan_id>"
```

### Partial failure handling

| Escenario | Accion |
|---|---|
| Todos ok | FASE 5 normal |
| 1 de N falla, otros ok | Usar N-1 resultados. Re-dispatch solo el fallido con timeout mayor. |
| >50% fallan | PARAR. Revisar prompt (probable Planner-Coder Gap). Volver a FASE 2. |
| Verifier falla | Re-dispatch verifier. Si falla 2x → SM sintetiza manualmente. |
| Timeout sin output | Aumentar timeout_secs 2x. Si falla de nuevo → tarea demasiado grande, dividir. |

---

## FASE 5 — VERIFICAR (Multi-Tier)

> "Give Claude a way to verify its work — it will 2-3x quality." — Boris Cherny
> "Evidence before claims, always." — Superpowers

### 5.1 Tier 1 — Checks deterministas (automatico)

El agente debe ejecutar ANTES de reportar:
- `npm run build` → 0 errors
- `npm test` → all pass (si hay tests)
- Linter → 0 new warnings

### 5.2 Tier 2 — SM verifica INDEPENDIENTEMENTE (supervisor pattern)

**NO confiar en el output del agente.** Ejecutar TU MISMO via SSH:

| Cambio | Comando SM | Esperar |
|---|---|---|
| UI (.tsx) | Chrome MCP → navega → screenshot | Visual correcto |
| API | `ssh-217 exec: "curl -sf url"` | 200 + JSON |
| BD | `ssh-217 exec: "docker exec supabase-db psql -c 'SELECT...'"` | Rows correctos |
| Build | `ssh-217 exec: "cd repo && npm run build 2>&1 \| tail -5"` | 0 errors |
| Deploy | `ssh-217 exec: "curl -sf health"` | Responde |
| Fix bug | Reproducir escenario original | Ya no falla |

Si agente dice "build ok" pero SM ve errores → agente alucino. NO aprobar.

### 5.3 Tier 3 — boris_verify (cierra ciclo)

```
boris_verify:
  what_changed: "[que — min 20 chars]"
  how_verified: "[comando ejecutado — min 20 chars]"
  result: "[output real — min 15 chars]"
```

**PROHIBIDO**: "Deberia funcionar", "Ya lo cambie" sin output, "Tests pasan" sin resultado.

### 5.4 Pedir mejoras (ciclo continuo)

```
"Que mas podria mejorar? Min 3 sugerencias."
```
Cada mejora NO trivial → nueva tarea (FASE 1). Seguir hasta "no encuentro mas mejoras".

**PUERTA 7**: Sin boris_verify con evidencia real = trabajo no existe.

---

## FASE 5B — ROLLBACK (si verificacion falla)

> Sin rollback, un fallo en FASE 5 deja el sistema en estado corrupto.

| Severidad | Accion |
|---|---|
| Build roto | `git revert HEAD` + notificar agente del error exacto → FASE 2 con fix |
| Test falla | Log del fallo como RED state → enviar prompt TDD (PA-6) al agente |
| BD corrupta | Rollback migration + restaurar backup → escalar a Carlos |
| Deploy roto | Rollback Coolify a version anterior + verificar health |

Procedimiento:
1. **Revert** el cambio que fallo (git revert, rollback migration, etc)
2. **Log** el fallo en KB: `kb_save key=fallo-<tema>-<YYMMDD>` con output exacto del error
3. **Diagnosticar**: fue Planner-Coder Gap (prompt ambiguo)? Bug real? Contexto stale?
4. **Re-planificar**: volver a FASE 2 con el diagnostico como input adicional
5. **Re-despachar**: NUNCA reenviar el mismo prompt — siempre corregido

---

## FASE 6 — GUARDAR (si no esta guardado, no existe)

### 6.1 Knowledge Hub
```
kb_save key=resultado-<tema>-<YYMMDD> category=notification project=<proyecto>
  value="[resumen + metricas + commits + feedback agente]"
```

### 6.2 Memory Palace
```
sypnose_add wing=<proyecto> room=<tema>
  content="[1-2 frases: que se logro, que aprendimos]"
```

### 6.3 Boris save state
```
boris_save_state:
  progress: "[que se completo]"
  next_step: "[que falta — o 'Tarea cerrada']"
```

### 6.4 Brain local
Actualizar `.brain/task.md` y `.brain/session-state.md`.

### 6.5 Siguiente wave o cerrar
- Mas waves → verificar W(N) ANTES de enviar W(N+1). Volver a FASE 2.
- Done → commit + push brain/memory. Reportar a Carlos.

---

## CHECKLIST RAPIDA

```
FASE 1 — LEER
  [ ] boris_start_task
  [ ] capture-pane TODOS los agentes
  [ ] git log repo destino
  [ ] kb_search + sypnose_search
  [ ] graphify o glob+grep

FASE 2 — PLANIFICAR
  [ ] GOAL global + GOAL por wave
  [ ] EMISOR + CONTEXTO + GRAPHIFY + WAVES + VERIFICACION + MEJORA + §11 + FIRMA
  [ ] tareas CONCRETAS (archivo, endpoint, tabla)
  [ ] archivos DISTINTOS por tarea
  [ ] output esperado EXPLICITO por tarea
  [ ] V1-V8 pasan

FASE 3 — APROBAR
  [ ] Carlos OK

FASE 4 — DESPACHAR
  [ ] send-keys o load-buffer
  [ ] spinner confirmado
  [ ] paralelizar otros agentes idle

FASE 5 — VERIFICAR
  [ ] Tier 1: build/test determinista
  [ ] Tier 2: SM verifica independiente (ssh exec)
  [ ] Tier 3: boris_verify con output real
  [ ] pedir mejoras al agente

FASE 5B — ROLLBACK (si fallo)
  [ ] revert cambio
  [ ] log fallo en KB
  [ ] diagnosticar causa
  [ ] re-planificar corregido

FASE 6 — GUARDAR
  [ ] kb_save resultado
  [ ] sypnose_add memoria
  [ ] boris_save_state
  [ ] .brain/ actualizado
```

---

## REGLAS DE HIERRO (10 Sypnose + 3 estado del arte)

### Sypnose:
1. **Sin boris_start_task no hay tarea**
2. **Sin OK Carlos no se envia**
3. **Sin verificacion no hay resultado** — hook bloquea commit
4. **Sin §11 el agente ejecuta ciego**
5. **Sin MEJORA CONTINUA el SM no aprende**
6. **Sin capture-pane no se despacha**
7. **NUNCA 2 prompts al mismo agente mientras trabaja**
8. **NUNCA dejar agentes idle si hay trabajo**
9. **NUNCA afirmar dato fiscal sin skill dgii-fiscal**
10. **NUNCA citar autorrelleno como decision de Carlos**

### Estado del arte (Boris + Karpathy + research):
11. **Plan antes de codigo** — nunca despachar sin plan escrito (Boris)
12. **GOAL por wave** — si no cabe en 1 linea, divide mas (Karpathy #4)
13. **Surgical changes** — el agente arregla SOLO lo pedido, no mejora adyacente (Karpathy #3)

---

## ERRORES HISTORICOS PREVENIDOS

| # | Error | Prevenido en |
|---|---|---|
| 1 | Duplicar investigacion | FASE 1 NO DUPLICAR |
| 2 | UX sin investigar mercado | FASE 1.3 KB search |
| 3 | Agente sin saber que APIs existian | FASE 2 CONTEXTO |
| 4 | Interrumpir agente activo | FASE 4 capture-pane |
| 5 | Prompt sin firma → KB no archivable | V1 FIRMA |
| 6 | "Deberia funcionar" sin build | FASE 5 boris_verify |
| 7 | 3 agentes idle mientras SM con 1 | FASE 4.3 paralelizar |
| 8 | Plan distorsionado por KB vs .brain/ | FASE 1.3 leer plan vivo |
| 9 | Rating prompt bloquea horas | FASE 4.2 dismiss |
| 10 | SM afirmo NCF falso | FASE 1.3 skill dgii-fiscal |
| 11 | Worker sin goal → output inutilizable | V8 GOAL obligatorio |
| 12 | 75% info perdida plan→ejecucion | FASE 2.3 Anti-Planner-Coder Gap |
| 13 | Fallo verificacion sin rollback | FASE 5B ROLLBACK |

---

## PATRONES AVANZADOS

### PA-1: Ultraplan (3 fuentes paralelas)

Antes de escribir prompt, consultar 3 fuentes EN PARALELO:
```
A: git log --oneline -10 + git diff --stat HEAD~3
B: kb_search + sypnose_search
C: graphify query + explain
```
Sintetizar ANTES de escribir. Si las 3 contradicen lo que Carlos pidio → reportar.

### PA-2: Context Freshness

| ctx agente | Accion |
|---|---|
| < 50% | Despachar normal |
| 50-75% | Priorizar tareas cortas |
| > 75% | `/compact` ANTES del prompt |
| > 90% | Nueva sesion obligatoria |

**SM tambien**: si el SM lleva >80% ctx, compactar con `/compact Foco en [tema actual]`.

### PA-3: Supervisor Independiente (Boris /goal pattern)

El SM ES el supervisor. Despues de que agente dice "done":
1. NO confiar — verificar TU MISMO via ssh exec
2. Si agente dice "build ok" pero SM ve error → agente alucino
3. Solo boris_verify con output que TU ejecutaste

### PA-4: Task List Compartida via KB

```
kb_save key=task-active-<agente>-<YYMMDD> category=task project=<proyecto>
  value="<agente> esta creando [X]. Otros agentes: NO crear duplicado."
```
En prompt a otro agente incluir: "[agente] esta haciendo [X]. Tu endpoint es [Y]."

### PA-5: SQUAD MODE

Cuando Carlos dice "prisas/rapido/Squad":
- Incluir: "Usa sub-agents Task. Min 6 sub-tasks simultaneos."
- Cada sub-task archivo DISTINTO
- Sub-agents: Sonnet 4.6 (NUNCA Opus)
- El Opus coordina, los Sonnet ejecutan

### PA-6: TDD Verification

```
## WAVE N — Fix [bug]
### RED: curl -sf url → 500 "column not found"
### GREEN: Archivo X linea Y — agregar columna Z al SELECT
### VERIFY:
- [ ] curl -sf url → 200 + JSON
- [ ] npm run build → 0 errors
```

### PA-7: Writer/Reviewer (Boris 2026)

Para cambios criticos, usar 2 agentes:
- Agente A implementa feature
- Agente B revisa en contexto fresco (sin bias hacia su propio codigo)
- Agente A aplica feedback del review

Implementar: despachar A primero, cuando A termina despachar B con "revisa el commit [hash] de [agente A]".

### PA-8: Competing Hypotheses (Boris debugging pattern)

Para bugs dificiles, despachar N agentes con teorias distintas:
- Cada agente investiga UNA hipotesis diferente
- Prompt explicito: "Tu hipotesis es [X]. Intenta probarla Y refutarla."
- La hipotesis que sobrevive es mas probable
- NUNCA despachar todos con la misma teoria

### PA-9: Batch Fan-Out (Boris /batch pattern)

Para migraciones masivas o tareas repetitivas sobre N archivos:
- Workers claw-dispatch: 1 worker por archivo, max_parallel = N
- Cada worker ejecuta la MISMA transformacion en SU archivo
- Verifier consolida todos los resultados
- Si hay archivos que dependen entre si → agrupar en mismo worker

### PA-10: Dependency Coordination

Cuando agente A depende del output de agente B:
1. Despachar B primero con KB save obligatorio al terminar
2. En prompt de A: "ESPERA a que KB `resultado-B-YYMMDD` exista antes de empezar"
3. O: SM coordina manualmente — cuando B termina, SM lee resultado y lo incluye INLINE en prompt de A
4. NUNCA decir "kb_read key=X" a agente 217 si KB fue guardado desde 67 (no sincronizados)

---

## TRAMPAS SYPNOSE

### T-1: Rating prompts bloquean agentes
"How is Claude doing? 0:Dismiss" → agente paralizado.
En CADA capture-pane buscar esto. Si aparece → `send-keys '0' Enter`.

### T-2: Autorrelleno NO es Carlos
Texto en buffer sin Enter = autorrelleno. Carlos NUNCA escribe sin enviar.
NUNCA citar autorrelleno como decision de Carlos en prompt.

### T-3: KB Hub 67 vs 217 NO sincronizados
SM MCP en 67, agentes en 217. NUNCA decir "kb_read key=X" si KB guardado desde 67.
Pasar contenido INLINE o guardar en AMBOS.

### T-4: tmux send-keys con newlines = desastre
Cada `\n` = Enter. Para prompts largos: escribir en /tmp, enviar pointer.

### T-5: /usr/bin/tmux ruta absoluta obligatoria
Wrapper tmux tiene hooks boris-protect que bloquean send-keys.

### T-6: Skill dgii-fiscal ANTES de dato fiscal
NUNCA afirmar NCF, e-CF, ITBIS%, formato desde memoria. Cargar skill primero.

---

## FUENTES Y ESTADO DEL ARTE

| Fuente | Que tomamos | Por que |
|---|---|---|
| **Boris Cherny 2026** | /goal, delegation philosophy, Writer/Reviewer, Competing Hypotheses, /batch fan-out, Agent Teams, /btw side-chain, /compact hints | Creador Claude Code, 20-30 PRs/dia, miles de sub-agents nocturnos |
| **Karpathy 4 Principles** | Think Before Coding (FASE 1), Simplicity First (regla 6), Surgical Changes (regla 7), Goal-Driven (V8+GOAL por wave) | 4 principios que eliminan 80% de errores agentes |
| **Anthropic /ultraplan** | 3 fuentes paralelas (PA-1) | 3 explorers encuentran lo que 1 pierde |
| **Anthropic /goal** | Completion condition auto-check cada turno | Supervisor independiente |
| **Anthropic Agent Teams** | Task list compartida (PA-4), inter-agent messaging | Modelo mental para KB-based coordination |
| **Anthropic Research System** | Fan-out/fan-in, 2 niveles paralelizacion | 90% reduccion tiempo en queries complejas |
| **GSD** | map→plan→execute→verify→ship pipeline | Context freshness por fase |
| **Superpowers** | Iron Laws, archivos distintos, TDD | Previene race conditions |
| **arXiv Planner-Coder Gap** | Monitor agent, contexto por tarea, output schema explicito | 75.3% fallos multi-agent por info perdida |
| **Multi-Tier Verification** | Determinista → SM independiente → boris_verify | 3 capas: automatico, humano, formal |
| **Context Engineering** | Gestionar QUE info llega al modelo, no solo COMO preguntar | Skill 2026: context > prompt engineering |
| **Spec-Driven Dev** | GOAL como spec ejecutable | Specs que validan, no solo documentan |
