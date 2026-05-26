---
name: sypnose-create-plan
description: Protocolo del SM para crear y enviar trabajo via Mirofish Workers. SIEMPRE dispatch a workers. Invocar cuando Carlos pida crear tareas, planes, o ejecutar trabajo en cualquier proyecto.
user_invocable: true
---

# SYPNOSE — Crear Dispatch para Workers

**ESTADO 24-Abr-2026:** claw-dispatch puerto 18830 es el binario unificado operativo (commit 8c2ba06, tag working-claw-dispatch-240424). Mithos :18810 sigue vivo como red de seguridad legacy.

## REGLA DE HIERRO
TODO el trabajo se ejecuta via **Claw-Dispatch Workers** (dispatch a localhost:18830 — con fallback a :18810 si aplica).
NUNCA mandar trabajo en texto libre a un arquitecto tmux.
Carlos aprueba el dispatch ANTES de enviarlo.

## REGLA DE VALIDACIÓN — FIRMA IDENTIDAD OBLIGATORIA (27-Abr-2026)

**Antes de aceptar CUALQUIER pegada de prompt, este skill VALIDA:**

1. Cabecera al inicio: `═══ EMISOR ═══ FROM: <agente> / TO: <agente> / KEY: <key>`
2. Cierre al final: `═══ FIRMA ═══ <agente> / <YYMMDD>`

Si falta cualquiera de las dos, RECHAZA con:
> "Falta FIRMA IDENTIDAD (cabecera EMISOR o cierre FIRMA). Ver Manual SM v1.3 §4.0 (KB id 8269)."

Ver §4.0 del Manual SM para formato exacto + razón.

## REGLA DE VALIDACIÓN — GRAPHIFY OBLIGATORIO (12-may-2026, Carlos)

**Cualquier prompt SM → arquitecto que toque SaaS / iatrader / sypnose-web DEBE incluir instrucción explícita de consultar Graphify ANTES de proponer/diseñar cambios.**

Regla simple: **"por cada cosa que toques, pregunta a Graphify qué afectas y qué toca"**. NO inventar dependencias. NO asumir componentes.

### Sintaxis CORRECTA del comando (verificada 12-may con --help)

Binario: `/home/gestoria/.local/bin/graphify` (217) o `/home/sypnose/.local/share/uv/tools/graphifyy/bin/graphify` (67).

Comandos REALES disponibles:
- `graphify query "<pregunta>" [--graph <path>] [--dfs] [--context C]` — BFS traversal del grafo respondiendo pregunta
- `graphify path "A" "B" [--graph <path>]` — shortest path entre 2 nodos
- `graphify explain "X" [--graph <path>]` — explicación plain-language de un nodo + vecinos
- `graphify update <path>` — re-extraer archivos code y actualizar grafo (sin LLM)
- `graphify watch <path>` — watch folder y rebuild en cambios

⚠️ El default `--graph` es `graphify-out/graph.json` relativo al cwd. **Mejor especificar siempre** la ruta absoluta para evitar ambigüedad.

### Paths reales de graphs producidos (12-may-2026)

| Repo | Graph path |
|---|---|
| .brain SM 217 | `/home/gestoria/.brain/graphify-out/graph.json` (369n/387l) |
| dgii-scraper-v2 | `/home/gestoria/dgii-scraper-v2/graphify-out/graph.json` (3279n/5289l) |
| FacturaScannerApp | `/home/gestoria/eas-builds/FacturaScannerApp/graphify-out/graph.json` (381n/549l) |
| gestion-contadoresrd | `/home/gestoria/builds/gestion-contadores-rd/graphify-out/graph.json` (2088n/3466l) |
| .brain 67 + sypnose-web + iatrader-rust + stratos-rs | conocidos por seguridad-server tras splits H2 |

### Bloque OBLIGATORIO en prompts SM→arquitecto

Cualquier prompt debe incluir una sección como esta:

```
## GRAPHIFY OBLIGATORIO (no inventar dependencias)

Por cada componente / función / endpoint / tabla / scheduler que vayas a tocar o proponer:

1. Pregunta a Graphify QUÉ AFECTAS y QUÉ TOCA:
   /home/gestoria/.local/bin/graphify query "¿dónde se usa <X>?" --graph <ruta-graph.json-de-tu-repo>

2. Si la respuesta no es clara, prueba:
   graphify explain "<componente>" --graph <ruta>
   graphify path "<origen>" "<destino>" --graph <ruta>

3. Reporta dependencias detectadas en la entrega (no asumir, verificar).

NO inventes componentes o relaciones. Si Graphify no devuelve nada útil para X, Glob+Read+Grep como fallback, pero declara explícitamente "Graphify no encontró X, fallback Glob+Grep".
```

Si el prompt SM omite este bloque para una tarea que toca código → SKILL RECHAZA con mensaje:
> "Falta sección GRAPHIFY OBLIGATORIO. Cualquier cambio en código SaaS / iatrader / sypnose-web requiere consultar grafo antes de proponer. Ver SKILL.md §Graphify."

## REGLA DE VALIDACIÓN — AUTORRELLENO NO ES CARLOS (12-may-2026, Carlos)

**Carlos NUNCA escribe en el buffer del agente y deja sin enviar Enter.**

Si el SM ve `❯ <texto>` en el tmux capture del agente y NO hay agente procesando (`Cogitating/Mustering/Shimmying/Doing/Imagining/...`) → es **autorrelleno garantizado**, NO palabra de Carlos.

Reglas del SM:
- NO interpretar texto en buffer sin procesar como decisión Carlos.
- NO enviar Enter al buffer para "ayudar a procesar autorrelleno".
- Si el SM necesita el agente actúe, redacta su propio mensaje (con §4.0+§11+§4.1) y pide OK explícito a Carlos antes de enviar.
- Si Carlos aprueba enviar otro mensaje, el `send-keys` escribe encima del autorrelleno sin problema (no requiere limpieza previa).

Frases típicas autorrelleno (cortas, sin firma): "okey/si/ponlo/avisame/install/commit this/instalo y pruebo/empieza wave X".
Mensajes de Carlos típicos: lenguaje natural más largo, con typos, mezcla mayúsculas/minúsculas, contexto adicional.

Si el SM duda → preguntar Carlos antes de procesar.

## REGLA DE VALIDACIÓN — SKILL DGII-FISCAL ANTES NCF (12-may-2026, Carlos)

**Antes de afirmar en prompt cualquier dato fiscal RD concreto (tipo NCF, e-CF, ITBIS%, sectores exentos, formatos 606/607/608, Norma 11-92, etc) el SM DEBE:**

1. Invocar skill `dgii-fiscal` o `dgii-apis-catalog` en cabeza del SM antes de redactar el prompt.
2. Citar la sección específica de la skill: "según skill dgii-fiscal §3, NCF tipo X = Y".
3. Si la skill no es clara o el SM duda → escribir "TBD: arquitecto verifica skill dgii-fiscal §X" en el prompt + pedir al arquitecto que confirme antes de tocar.
4. **NUNCA afirmar tipos NCF concretos de memoria** + esperar que el arquitecto detecte el error.

Caso real 12-may: SM afirmó "E12 = Gubernamental Electrónico" sin verificar. **FALSO** (E12 NO existe en spec DGII; Gubernamental Electrónico = E45). FacturaIA §11 corrigió + descubrió bug F8 oculto (validTypes invertidos). Sin §11 + buen criterio, el bug F2 habría quedado mal diagnosticado.

Aplica a: tipos NCF/e-CF (B01-B17, E31-E47), cálculo ITBIS (18%/16%/0%), Norma 11-92 retenciones, formatos DGII (606/607/608, IT-1, IR-2, IR-3), tarjeta coordenadas OFV 3FA, plazos fiscales, endpoints OFV, TSS, SharePoint datasets.

## REGLA DE VALIDACIÓN — CLAW-DISPATCH LIMITACIONES (12-may-2026, descubierto SM)

**Workers claw-dispatch + Gemini razonan pero NO ejecutan bash multi-step.**

- ✅ `openai/gemini-2.5-pro` vía cliproxy:8317 → gemini-proxy Cloud Run → Vertex AI eagleview-prod: funciona para researcher/planner/verifier.
- ✅ `openai/gemini-2.5-flash`: funciona para verifiers rápidos.
- ❌ `cerebras-qwen3-235b`: CUELGA (key Cerebras Cloud expired).
- ❌ `claude-sonnet-4-6` / `sonnet`: falla `missing_credentials` (claw daemon sin ANTHROPIC_AUTH_TOKEN).
- ❌ `gemini-2.5-flash` sin prefix: rechazado `invalid_model_syntax`.

**Para tareas que requieren ejecución real (git clone + sed + jq + edición de archivos + builds + deploys):**
- claw-dispatch + Gemini NO SIRVE — Gemini genera texto pero no edita disco.
- Usar agente humano tmux (Claude Code real con tools Edit/Write/Bash) vía send-keys + sm-tmux.
- O SM directo via `mcp__ssh-*__exec` si el scope permite (scripts de infra Sypnose, NO código producto SaaS).

Cuando el SM necesite editar archivos en un repo de producto, despachar a tmux humano, NUNCA claw workers Gemini esperando edits.

## REGLA DE VALIDACIÓN — MEJORA CONTINUA OBLIGATORIA (27-Abr-2026)

**Antes de enviar CUALQUIER dispatch o prompt SM→arquitecto, este skill VALIDA presencia de la sección `## MEJORA CONTINUA — Retroalimentación obligatoria al SM` con las 3 dimensiones (Sistema / Prompt / Flujo).**

Si el prompt NO incluye la sección, el skill RECHAZA con mensaje:
> "Falta sección MEJORA CONTINUA. Añádela y reintenta. Ver Manual SM v1.2 §4.1 (KB id 8269)."

Texto literal del bloque a incluir (entre "Criterios de éxito" y "Entrega"):

```
## MEJORA CONTINUA — Retroalimentación obligatoria al SM

Antes de hacer kb_save del resultado final, AÑADE una sección
"## Feedback al SM" con análisis honesto en 3 dimensiones.
Si todo encajó, indícalo: "0 hallazgos en esta dimensión".

### Dimensión 1 — Sistema / Repo
¿Qué del prompt NO encajaba con la realidad técnica de tu repo, schema, runtime, deps?
- Falsos positivos (paths, nombres, comandos que no existen)
- Estado real distinto al asumido
- Deuda técnica que el SM ignoró pero tú conoces

### Dimensión 2 — Prompt / Comunicación
¿Qué del prompt fue ambiguo, contradictorio, redundante?
- Etiquetas KB BUS faltantes
- Modelo/profile inapropiado
- Verificación no falsable
- Reglas críticas omitidas

### Dimensión 3 — Flujo / Proceso
¿Qué del SM→Wave→Verify→Commit no funcionó?
- Wave secuencial que debió paralelizar
- Boris tag innecesario o faltante
- Anti-colisión no observada
- Pasos repetidos
- Falta canal de bloqueo claro
```

**Por qué**: SM no aprende sin feedback estructurado. Sin §4.1, el SM repite mismos errores wave tras wave. Ver Manual SM v1.2 §4.1 + §8 entrada #9.

## FLUJO: 5 PASOS — Sin excepciones

### PASO 1 — Investigar (30 seg max)

Antes de crear el dispatch:
0. `sypnose_search` del tema → Memory Palace (alguien ya trabajo en esto?)
   Fallback: `curl -s -X POST http://localhost:18792/sypnose_search -H "Content-Type: application/json" -d '{"params":{"query":"TEMA","limit":5}}'`
1. `kb_search` del tema → lecciones, errores previos
2. `git log --oneline -5` del repo → ultimos commits
3. NO crear trabajo repetido

### PASO 2 — Crear dispatch JSON

Toda tarea se convierte en un dispatch JSON con esta estructura:

```json
{
  "description": "Que hace este dispatch — una linea",
  "workspace": "/home/gestoria/[proyecto]",
  "keep_workspace": true,
  "max_parallel": 8,
  "tasks": [
    {
      "id": "00000000-0000-0000-0000-000000000000",
      "profile": "executor|executor-pro|verifier|researcher|debugger|planner",
      "description": "Tarea CONCRETA — que hacer, que archivos, que comando",
      "model": "openai/gemini-2.5-pro",
      "timeout_secs": 300,
      "depends_on": []
    }
  ]
}
```

**REGLAS DE FORMATO (aprendidas 12-may-2026, bug claw):**

1. **`id` debe ser UUID**, no string corto. Generar con `uuid.uuid4()` o `cat /proc/sys/kernel/random/uuid`. claw rechaza ids no-UUID con `UUID parsing failed`.
2. **`workspace` debe existir antes del dispatch** (`mkdir -p` previo). claw valida workspace antes de ejecutar tasks y aborta con `workspace ... no existe`.
3. **`depends_on` usa los UUIDs de otros tasks**, no nombres cortos.

### Perfiles de workers:

| Profile | Modelo default (CANÓNICO 12-may-2026) | Usar para |
|---|---|---|
| executor | `openai/gemini-2.5-pro` | Comandos bash CORTOS (curl, health checks, git log). NO multi-step git clone+sed+jq — Gemini razona pero NO ejecuta bash de verdad |
| executor-pro | ⚠️ NO USAR HASTA REPARAR | claude-sonnet-4-6 falla `missing_credentials` (claw daemon sin ANTHROPIC_AUTH_TOKEN). Fallback: SM directo via mcp__ssh-*__exec si es script de infra Sypnose |
| verifier | `openai/gemini-2.5-flash` | Confirmar output — HTTP directo sin tools, sin streaming, <5s |
| researcher | `openai/gemini-2.5-pro` | Leer codigo/docs, producir analisis estructurado (vía Vertex AI eagleview-prod) |
| debugger | ⚠️ NO USAR | claude-sonnet-4-6 sin ANTHROPIC_AUTH_TOKEN en daemon. Fallback: agente humano tmux |
| planner | `openai/gemini-2.5-pro` | Crear sub-planes JSON, razonar arquitectura |

### Modelos canónicos (12-may-2026):

| Modelo en JSON                    | Va a                                      | Estado |
|-----------------------------------|-------------------------------------------|--------|
| `openai/gemini-2.5-pro`           | cliproxy:8317 → gemini-proxy Cloud Run → Vertex AI eagleview-prod | ✅ OK — usar SIEMPRE |
| `openai/gemini-2.5-flash`         | mismo flow                                | ✅ OK — verifiers |
| `cerebras-qwen3-235b`             | Cerebras Cloud                            | ❌ CUELGA (key expired) |
| `claude-sonnet-4-6` / `sonnet`    | Anthropic API                             | ❌ FALTA ANTHROPIC_AUTH_TOKEN en claw daemon |
| `gemini-2.5-flash` (sin prefix)   | —                                         | ❌ Rechazo `invalid_model_syntax` |

### ⚠️ Limitación crítica claw-dispatch + Gemini

Gemini-pro vía cliproxy **razona pero NO ejecuta bash multi-step**. Sirve para:
- Leer archivos (researcher)
- Generar texto/JSON (planner)
- Validar/clasificar output (verifier)

NO sirve para:
- `git clone` + edición de archivos (executor-pro tradicional)
- Builds, deploys, scraping con efectos en disco
- Sed/jq/awk encadenados

**Cuando necesites edit real** → tmux agente humano Claude Code (sm-tmux send), o SM mismo via mcp__ssh-*__exec si es script de infra Sypnose (no código de producto SaaS).

### Waves y verificacion (LEY DE PRODUCCION):

**El dispatch SIEMPRE tiene verificacion entre waves.**

Patron obligatorio:
- **Wave 1**: tareas SIN dependencias → `depends_on: []` → paralelo
- **Tarea verifier**: confirma que Wave 1 funciona → `depends_on: ["ids-wave1"]`
- **Wave 2**: tareas que dependen de Wave 1 → `depends_on: ["verifier-wave1"]`

**Si el verifier falla** → todo se detiene. El SM revisa el output y decide.

### Como dividir una tarea grande:

| Tarea original | Wave 1 (paralelo) | Verifier | Wave 2 |
|---|---|---|---|
| Fix un bug | researcher lee codigo | verifier: build compila? | debugger aplica fix |
| Feature nueva | researcher analiza contexto + executor hace backup | verifier: tag creado? | executor-pro implementa |
| Scraping batch | N executors en paralelo (uno por cliente) | verifier: todos 200 OK? | researcher resume resultados |
| Health check | 5 executors (sistema, docker, apps, BD, red) | — (una sola wave) | — |
| Deploy | executor: git push | verifier: Coolify status? | executor: curl health |

### REGLA: Descripcion del worker debe ser CONCRETA

**MAL** (vago):
```json
{"description": "Arregla el bug de formularios"}
```

**BIEN** (concreto):
```json
{"description": "Lee src/app/formularios/607/page.tsx y src/app/formularios/606/page.tsx. Busca GoTrueClient race condition en useEffect. Identifica por que 607 redirige a 606/IT-1. Guarda hallazgos en /tmp/bug607-research.md"}
```

El worker NO tiene contexto previo. Dale TODO lo que necesita saber en la descripcion.

---

## PASO 3 — Mostrar a Carlos

- Presentar el dispatch JSON completo
- Carlos dice "okey" o pide cambios
- NUNCA enviar sin aprobacion de Carlos

## PASO 4 — Enviar dispatch

### Via SM (desde Windows, hop por Sypnose):
```bash
ssh -p 2024 sypnose@62.171.147.46 "ssh -p 2024 gestoria@217.216.48.91 'curl -s -X POST http://localhost:18830/dispatch -H \"Content-Type: application/json\" -d \"[DISPATCH_JSON_ESCAPED]\"'"
```

### Via Claw (Carlos en tmux `claw`):
Carlos entra a la sesion claw y dice la tarea en lenguaje natural.
Claw convierte a dispatch JSON y ejecuta automaticamente.
```bash
ssh contabo -t "tmux attach -t claw"
# Dentro: "scraping DGII para los 5 clientes nuevos"
```

### Via directa en Contabo:
```bash
curl -s -X POST http://localhost:18830/dispatch \
  -H "Content-Type: application/json" \
  -d '[DISPATCH_JSON]'
```

## PASO 5 — Verificar resultado y reportar

### Leer resultado:
```bash
# Dispatch devuelve JSON con plan_id y results
# Verificar:
# - tasks_completed == total
# - tasks_failed == 0
# - Leer output de cada worker
```

### Si todo pasa:
```bash
curl -s -X POST http://localhost:18791/api/save \
  -H "Content-Type: application/json" \
  -d '{
    "key": "resultado-workers-[nombre]-[fecha]",
    "category": "notification",
    "project": "[proyecto]",
    "value": "DONE: [que se completo]\nWORKERS: [cuantos, que perfiles]\nVERIFICADO: [output del verifier]\nDESCUBRIMIENTOS: [si hay]\nSUGERENCIAS: [proximo dispatch recomendado]"
  }'
```

### Si algo falla:
1. Leer output del worker que fallo
2. NO re-dispatch inmediato — entender por que fallo
3. Si es error de prompt → corregir descripcion → re-dispatch
4. Si es error de codigo/infra → crear nuevo dispatch con debugger
5. Si es error grave → reportar a Carlos, PARAR

---

## LEY DE VERIFICACION ENTRE WAVES (27-Mar-2026)

**NUNCA avanzar a Wave N+1 sin que el verifier confirme Wave N.**

El dispatch tiene esto incorporado via `depends_on`. Pero el SM tambien debe verificar:
- Leer el output del verifier
- Si dice "BUILD FAILED" o similar → NO enviar Wave 2
- Si el dispatch tiene 1 sola wave sin verifier → aceptable solo para health checks

**Por que existe**: GestoriaRD 27-Mar-2026, cambios en cascada sin verificar, SaaS caido.

---

## LEY DE EVIDENCIA (28-Mar-2026)

**Sin output real del worker, el trabajo NO existio.**

| Cambio | Evidencia del worker |
|---|---|
| Codigo | build output + test output |
| API | curl response con status code |
| BD | SELECT query result |
| Docker | docker ps + curl health |
| Deploy | curl al endpoint final |
| Scraping | JSON response del endpoint |

---

## EJEMPLOS REALES

### Fix bug GestoriaRD:
```json
{
  "description": "Fix BUG-1: /formularios/607/ routing race condition",
  "workspace": "/home/gestoria/gestion-contadoresrd",
  "keep_workspace": true,
  "max_parallel": 3,
  "tasks": [
    {
      "id": "research",
      "profile": "researcher",
      "description": "Lee src/app/formularios/607/ y src/app/formularios/606/. Identifica por que 607 redirige a 606. Busca GoTrueClient race condition en useEffect. Guarda hallazgos en /tmp/bug607-research.md",
      "model": "gemini-2.5-flash"
    },
    {
      "id": "fix",
      "profile": "debugger",
      "description": "Lee /tmp/bug607-research.md. Corrige el bug de routing en /formularios/607/. Aplica fix. Ejecuta npm run build para verificar que compila.",
      "depends_on": ["research"],
      "model": "claude-sonnet-4-6"
    },
    {
      "id": "verify",
      "profile": "verifier",
      "description": "Ejecuta: cd /home/gestoria/gestion-contadoresrd && npm run build 2>&1 | tail -5. Reporta BUILD OK o BUILD FAILED.",
      "depends_on": ["fix"],
      "model": "cerebras-qwen3-235b"
    }
  ]
}
```

### Scraping DGII batch:
```json
{
  "description": "Scraping DGII notificaciones para 5 clientes",
  "workspace": "/home/gestoria/dgii-scraper-v2",
  "max_parallel": 5,
  "tasks": [
    {"id":"c1","profile":"executor","description":"Ejecuta: curl -sf http://localhost:8321/scrape -X POST -H 'Content-Type: application/json' -d '{\"rnc\":\"131047939\",\"actions\":[\"login\",\"notifications\"]}'","model":"cerebras-qwen3-235b"},
    {"id":"c2","profile":"executor","description":"Ejecuta: curl -sf http://localhost:8321/scrape -X POST -H 'Content-Type: application/json' -d '{\"rnc\":\"101234567\",\"actions\":[\"login\",\"notifications\"]}'","model":"cerebras-qwen3-235b"},
    {"id":"c3","profile":"executor","description":"Ejecuta: curl -sf http://localhost:8321/scrape -X POST -H 'Content-Type: application/json' -d '{\"rnc\":\"130567890\",\"actions\":[\"login\",\"notifications\"]}'","model":"cerebras-qwen3-235b"},
    {"id":"c4","profile":"executor","description":"Ejecuta: curl -sf http://localhost:8321/scrape -X POST -H 'Content-Type: application/json' -d '{\"rnc\":\"401987654\",\"actions\":[\"login\",\"notifications\"]}'","model":"cerebras-qwen3-235b"},
    {"id":"c5","profile":"executor","description":"Ejecuta: curl -sf http://localhost:8321/scrape -X POST -H 'Content-Type: application/json' -d '{\"rnc\":\"131999888\",\"actions\":[\"login\",\"notifications\"]}'","model":"cerebras-qwen3-235b"}
  ]
}
```

### Health check completo:
```json
{
  "description": "Health check completo de todos los servicios",
  "max_parallel": 5,
  "tasks": [
    {"id":"sys","profile":"executor","description":"Ejecuta: uptime && free -h && df -h /","model":"cerebras-qwen3-235b"},
    {"id":"docker","profile":"executor","description":"Ejecuta: docker ps --format 'table {{.Names}}\\t{{.Status}}' | head -25","model":"cerebras-qwen3-235b"},
    {"id":"apps","profile":"executor","description":"Ejecuta: curl -sf http://localhost:3000/api/health && curl -sf http://localhost:3080 | head -3","model":"cerebras-qwen3-235b"},
    {"id":"services","profile":"executor","description":"Ejecuta: systemctl is-active dgii-scraper-api mithos-dispatch cliproxyapi","model":"cerebras-qwen3-235b"},
    {"id":"network","profile":"executor","description":"Ejecuta: ss -tn state established | grep -v 127.0.0.1 | grep -v 186.7. | grep -v 190.167. | grep -v :443 | head -10","model":"cerebras-qwen3-235b"}
  ]
}
```

### Feature nueva compleja (multi-wave):
```json
{
  "description": "Implementar endpoint /api/clientes/bulk-import en GestoriaRD",
  "workspace": "/home/gestoria/gestion-contadoresrd",
  "keep_workspace": true,
  "max_parallel": 4,
  "tasks": [
    {
      "id": "backup",
      "profile": "executor",
      "description": "Ejecuta: cd /home/gestoria/gestion-contadoresrd && git pull origin main && git tag pre-bulk-import-20260420 -m 'Punto de retorno' && git push origin pre-bulk-import-20260420",
      "model": "cerebras-qwen3-235b"
    },
    {
      "id": "research",
      "profile": "researcher",
      "description": "Lee src/app/api/clientes/ completo. Identifica patron de endpoints existentes (auth, validation, BD). Guarda estructura en /tmp/clientes-api-pattern.md",
      "model": "gemini-2.5-flash"
    },
    {
      "id": "implement",
      "profile": "executor-pro",
      "description": "Lee /tmp/clientes-api-pattern.md. Crea src/app/api/clientes/bulk-import/route.ts siguiendo el mismo patron. Debe: validar CSV, insertar en BD via Supabase, retornar count. Maximo 100 filas por request.",
      "depends_on": ["backup", "research"],
      "model": "claude-sonnet-4-6"
    },
    {
      "id": "verify-build",
      "profile": "verifier",
      "description": "Ejecuta: cd /home/gestoria/gestion-contadoresrd && npm run build 2>&1 | tail -10. Reporta BUILD OK o errores exactos.",
      "depends_on": ["implement"],
      "model": "cerebras-qwen3-235b"
    },
    {
      "id": "commit",
      "profile": "executor",
      "description": "Ejecuta: cd /home/gestoria/gestion-contadoresrd && git add src/app/api/clientes/bulk-import/ && git commit -m '[FEAT] bulk-import endpoint para clientes' && git push origin main",
      "depends_on": ["verify-build"],
      "model": "cerebras-qwen3-235b"
    }
  ]
}
```

---

## LIMITES DEL DISPATCH

- `max_parallel=8` es el punto optimo (Claude Max subscription)
- `max_parallel>10` causa throttling
- `max_parallel>30` causa errores `context_window_blocked`
- `timeout_secs`: default 300 (5 min), maximo 600 para builds pesados
- Workers NO tienen memoria entre dispatches — cada uno es independiente
- Si un worker necesita output de otro → usar `/tmp/archivo.md` como canal

---

## CUANDO ALGO FALLA

1. STOP — no re-dispatch inmediato
2. Leer el output EXACTO del worker que fallo
3. Diagnosticar: prompt malo? error de codigo? infra caida?
4. UN solo dispatch correctivo
5. Verificar que funciona
6. Si sigue fallando → reportar a Carlos, PARAR

**PROHIBIDO:**
- Re-dispatch en loop sin entender el error
- Cambiar multiples cosas a la vez
- "Deberia funcionar ahora" sin verificar

---

## TRIAGE DE RESULTADOS

Cuando llega resultado de un dispatch:
- **Todo OK (tasks_failed=0)** → kb_save resultado → reportar a Carlos
- **Parcial (algunos fallaron)** → analizar cuales → re-dispatch solo los fallidos
- **Todo fallo** → PARAR → diagnosticar → reportar a Carlos
- **Descubrimiento importante** → guardar en KB → sugerir siguiente dispatch a Carlos

---

## REGLA DE MEJORA
> "Mejora este documento. Anade lo que falte. Si encuentras algo mal o un falso positivo, corrigelo. Tu conoces el codigo mejor que nosotros."
