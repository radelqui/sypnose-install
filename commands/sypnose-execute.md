---
name: sypnose-execute
description: Arsenal Sypnose v6 — UNICO comando para cualquier arquitecto. Piramide 3 capas (sin Sonnet capataz). Workers Kimi K2.6 via CLIProxy + Verifiers Gemini Flash (ACTIVOS). Boris Atomico integrado. Gemini Gate con 7 etiquetas (CRITERIO nuevo). Acceptance Gate obligatorio. Karpathy + Boris embebidos. 2 memorias (KB+Palace) con LightRAG auto.
user_invocable: true
---

# /sypnose-execute [tarea | plan.md] [--flags]

Skill autocontenido. El arquitecto invoca y tiene TODO: principios, flujo, dispatch, memorias, git, reporte. Cualquier colaborador del mundo lo ejecuta sin leer otros archivos.

**Flags disponibles:**
- `--dry-run` → muestra plan, costo, PARL, pero NO despacha
- `--resume [task-name]` → retoma tarea interrumpida desde state file
- `--skip-parl micro` → tarea trivial de 1 solo paso
- `--force` → salta pre-flight health check (NO recomendado)

---

## PRINCIPIOS DE EJECUCION (Karpathy — LEER ANTES DE ACTUAR)

**0. Velocity First (LEY DE ORO)** — Con Kimi K2.6, `max_parallel` SIEMPRE = 300 (limite confirmado por Kimi API). NUNCA uses 10 o 30 — son reliquias de cuando usabamos Sonnet. Si puedes enviar 300 workers, ENVIALOS. Velocidad es la primera orden.
**1. Think Before Coding** — No asumir. Leer lo que existe antes de cambiar. Si hay duda, Wave 0 researcher.
**2. Simplicity First** — Minimo codigo que resuelve el problema. Sin features extra, sin abstracciones prematuras.
**3. Surgical Changes** — Tocar solo lo necesario. 1 worker = 1 archivo. No "mejorar" codigo adyacente.
**4. Goal-Driven** — Definir criterio de exito ANTES de despachar. No "deberia funcionar" — verificar con output real.
**5. Check Errors First** — Antes de cada wave, consultar `kb_search category=lesson project=[proyecto]`. Error repetido = trabajo rechazado.

---

## ARQUITECTURA v6 — PIRAMIDE 3 CAPAS + BORIS ATOMICO

```
ARQUITECTO (Opus) — planifica, dispatch directo, verifica, reporta
  └→ WORKERS KIMI K2.6 via CLIProxy (Mithos :18810, 300 por wave con Kimi K2.6) — ejecutan + auto-verifican + autocorrigen
       └→ VERIFIERS GEMINI FLASH via CLIProxy (solo si build/E2E requerido) — PASS/FAIL con output real
```

**Capacidad**: 300 workers simultaneos por dispatch con Kimi K2.6 (limite confirmado).
**Regla de oro**: El arquitecto hace curl directo via `mithos-dispatch-gated.sh`. Workers tienen Boris Atomico embebido — se auto-verifican hasta 3 intentos, reportan DONE o FAILED.

### MODELOS FIJOS (ACTIVOS — v6.1 Contabo + Sypnose)

| Capa | Modelo PRIMARIO | Via | ID dispatch | Notas |
|---|---|---|---|---|
| Workers EXECUTOR | Gemini Flash | CLIProxy :8317 | `gemini-2.5-flash` | rapido, no-thinking, 300 paralelo |
| Workers complejos | Kimi K2.6 | CLIProxy :8317 | `kimi-k2.6` | thinking model — REQUIERE `max_tokens>=4096` o retorna vacio |
| Gate | Gemini Flash | CLIProxy :8317 | `gemini-2.5-flash` | |
| Verifier final | Gemini Flash | CLIProxy :8317 | `gemini-2.5-flash` | PASS/FAIL con output literal |

**REGLA ORO de max_tokens por modelo (SOLO 2 modelos oficiales desde 23-Abr-2026):**
- `gemini-2.5-flash`: max_tokens >= 500 suficiente
- `kimi-k2.6`: **max_tokens >= 4096 OBLIGATORIO** (consume tokens en reasoning_content antes de responder; con <4096 retorna content vacio aunque no haya error)

**MODELOS UNICOS OFICIALES**: `kimi-k2.6` + `gemini-2.5-flash`. Todo lo demas (haiku, sonnet, deepseek, cerebras, qwen, gemini-pro, gemini-flash-lite, kimi-k2 sin .6, kimi-k2-0905, gpt-oss, gemini-2.0, gemini-3-*) esta DEPRECATED en CLIProxy y NO se debe usar. Si aparecen en dispatches = bug de Mithos ignorando el `"model"` specified.

---

## GOTCHAS CONTABO v6.2 (aprendidos en sesiones reales — 23-Abr-2026)

1. **`workspace` va POR TASK, no al root del JSON**
   Mithos ignora `workspace` al nivel raiz → usa `/home/gestoria` → error `broad directory`.
   FIX: `"workspace": "/ruta/proyecto"` DENTRO de cada task del array `tasks[]`.

2. **Mithos profile `executor` mapea a haiku en Contabo, NO kimi-k2.6**
   Si no especificas `"model"`, usa haiku default. En Sypnose el profile mapea a kimi.
   FIX: SIEMPRE pasar `"model": "kimi-k2.6"` o `"model": "gemini-2.5-flash"` explicito.

3. **`max_tokens` bajo silencia el error — retorna content vacio sin warning**
   Kimi-k2.6 es thinking model: consume 500-4000 tokens en `reasoning_content` ANTES de emitir `content`.
   Con max_tokens bajo retorna `content: ""` sin error → worker dice `done` pero no hizo nada.
   FIX: gemini-flash `max_tokens >= 500`; kimi-k2.6 `max_tokens >= 4096`.

4. **Prompts deben ser IDEMPOTENTES (crítico)**
   Si worker falla y relanzas, `Busca X y reemplaza con Y` sin guard aplica el cambio 2 veces → duplicados.
   FIX: en cada CAMBIO añadir: `Si la cadena Y ya existe en el archivo, NO duplicar, reportar IDEMPOTENT_OK para este cambio`.

5. **El verificador worker corre en workspace aislado**
   `grep /ruta/archivo` dentro de un worker puede reportar NO_MATCH aunque el host si vea match.
   FIX: el verificador final es GEMINI FLASH via dispatch con `workspace` igual al arquitecto, ejecutando comandos con round-trip al sistema real (curl HTTP, psql query, docker exec), NO grep a archivo local del sandbox.

---

## PASO -1 — PRE-FLIGHT HEALTH CHECK (automatico, antes de TODO)

Verificar que la infra esta viva. Si algo cae, PARAR — no trabajar sobre infra rota.

```bash
CLIPROXY_KEY="sk-GazR6oQwVsbxdaMK5PE_Ht-88lUn3IALdwtwyZg6eWo"

# Mithos (workers)
curl -sf http://localhost:18810/health | grep -q '"status":"ok"' || { echo "MITHOS DOWN"; exit 1; }

# CLIProxy (workers + verifiers + gate)
curl -sf http://localhost:8317/v1/chat/completions \
  -H "Authorization: Bearer $CLIPROXY_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"kimi-k2.6","messages":[{"role":"user","content":"ping"}],"max_tokens":5}' \
  | grep -q '"model"' || { echo "CLIPROXY/KIMI DOWN"; exit 1; }

# KB (memoria 1)
curl -sf http://localhost:18791/health || { echo "KB DOWN"; exit 1; }

# Memory Palace (memoria 2, alimenta LightRAG auto via cron 4h)
curl -sf http://localhost:18792/health || { echo "PALACE DOWN"; exit 1; }

# Scripts obligatorios existen
test -x /home/gestoria/scripts/gemini-gate-execute.sh || { echo "GATE SCRIPT MISSING"; exit 1; }
test -x /home/gestoria/scripts/mithos-dispatch-gated.sh || { echo "WRAPPER MISSING"; exit 1; }

# Git pull funciona
cd [proyecto] && git pull origin $(git branch --show-current) || { echo "GIT DOWN"; exit 1; }

# Recursos: disco > 5GB, RAM < 85%
df -h / | awk 'NR==2 {gsub(/%/,"",$5); if($5>90) {print "DISK FULL"; exit 1}}'
free | awk 'NR==2 {if($3/$2*100 > 85) {print "RAM HIGH"; exit 1}}'
```

Si `--force` → saltar. Si algo cae sin `--force` → abortar con mensaje exacto.

---

## PASO 0 — LOCK + CONTEXTO (obligatorio)

### 0.1 Lock file — evitar colisiones entre arquitectos

```bash
LOCK=/tmp/sypnose-execute-[proyecto].lock
if [ -f "$LOCK" ]; then
  PID=$(cat "$LOCK")
  if kill -0 $PID 2>/dev/null; then
    echo "LOCK activo por PID $PID. Otro arquitecto trabaja en este proyecto. Abortar."
    exit 1
  fi
fi
echo $$ > "$LOCK"
trap "rm -f $LOCK" EXIT
```

### 0.2 Boris start (anti-repeticion + git pull + tag)

```
boris_start_task(task_name="[nombre]", task_description="[que]")
# Si retorna "YA COMPLETADA" -> PARAR. No repetir.
```

### 0.3 Errores previos — NO repetir lo que ya fallo

```bash
# Por area que vas a tocar (PASO 0 — antes de planificar)
kb_search "lesson-frontend project=[proyecto] category=lesson"   # si tocas UI
kb_search "lesson-bd project=[proyecto] category=lesson"         # si tocas BD
kb_search "lesson-scripts project=[proyecto] category=lesson"    # si tocas bash/cron
kb_search "lesson-infra project=[proyecto] category=lesson"      # si tocas Docker/deploy
kb_search "lesson-api project=[proyecto] category=lesson"        # si tocas endpoints
kb_search "lesson-workers project=[proyecto] category=lesson"    # si despachas a Mithos
```

Si hay error que aplica a tu tarea → leer el FIX antes de continuar. Error repetido = rechazo automatico.

### 0.4 Memoria — buscar si alguien ya hizo algo similar

```bash
# Memory Palace (semantic search cross-project)
curl -s -X POST http://localhost:18792/sypnose_search \
  -H "Content-Type: application/json" \
  -d '{"params":{"query":"[tema]"}}'

# KB (contexto previo del proyecto)
kb_search("[tema]")
```

### 0.5 State file — para sobrevivir reset de contexto

```bash
STATE=.brain/sypnose-state-[task].json
mkdir -p .brain
cat > "$STATE" <<EOF
{
  "task": "[nombre]",
  "started": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "phase": "planning",
  "waves_total": 0,
  "waves_completed": 0,
  "files_touched": [],
  "commits": [],
  "workers_dispatched": 0,
  "errors": []
}
EOF
```

Si contexto se resetea → `/sypnose-execute --resume [task]` lee este JSON y retoma.

---

## PASO 1 — PLANIFICAR WAVES (el trabajo real del arquitecto)

El arquitecto convierte cada accion en instrucciones EXACTAS para workers.

### Regla de planificacion

| Carlos dice | El arquitecto hace |
|---|---|
| "arregla X" | Wave 0 researcher → Wave 1 executor con cambio exacto |
| "implementa Y" | Divide en archivos, 1 worker por archivo, instrucciones line-by-line |
| "investiga Z" | Wave researcher → resultados en /tmp/ → arquitecto lee → Wave executor |
| tarea trivial 1 paso | `--skip-parl micro` + 1 worker directo |

### Formato de instruccion de worker (OBLIGATORIO — 90% del exito)

```
CONTEXTO: [proyecto], [que estamos haciendo y por que]
CRITERIO: [comportamiento que el usuario final debe poder verificar — copiar del plan]
ARCHIVO: /ruta/exacta/al/archivo.py
ACCION: editar | crear | ejecutar
CAMBIO: linea 45, cambia `return x*2` por `return x*3`
  (o si es crear: contenido completo del archivo)
VERIFICACION: python3 -c "from archivo import func; assert func(2)==6; print('OK')"
SI FALLA: reportar error exacto, NO improvisar cambios adicionales
```

El CRITERIO no es para que el worker lo ejecute — es para que entienda el intent y no tome atajos que "pasan la verificacion pero rompen el comportamiento real".

**PROHIBIDO en prompts de workers:**
- "Mejora el codigo" (subjetivo)
- "Implementa la feature" (vago)
- "Revisa y arregla" (sin target)
- Dar mas de 1 tarea por worker

### Anti-colision (REGLA ABSOLUTA)

1 archivo = 1 worker. NUNCA 2 workers sobre el mismo archivo. Antes de dispatch, crear file_map:

```
worker-1 → /src/api/auth.ts
worker-2 → /src/api/users.ts
worker-3 → /src/db/schema.sql
```

Si 2 tareas necesitan el mismo archivo → waves diferentes (Wave 1 lo crea, Wave 2 lo edita).

### 7 etiquetas obligatorias del plan (Gate las valida — v6)

```
PLAN: [descripcion en una linea]
TAREA: [que debe ejecutar, concreto]
MODELO: Arquitecto claude-opus-4-6. Workers kimi-k2.6 via CLIProxy. Verifiers gemini-2.5-flash via CLIProxy
BORIS: git pull origin main + git tag pre-[nombre]-[fecha]
VERIFICACION: [comando bash concreto por wave]
EVIDENCIA: [que archivos/outputs deben existir al terminar]
CRITERIO: [comportamiento testeable desde perspectiva del usuario — ej: "GET /api/historial devuelve array con campo periodo", "boton Generar aparece en azul", "error 422 ya no ocurre al enviar el form"]
> ❌ MAL: "el archivo ~/.claude/commands/X.md existe" (eso es EVIDENCIA tecnica, no CRITERIO)
> ✅ BIEN: "el agente puede invocar /X sin configuracion adicional" (comportamiento testeable)
```

**CRITERIO es la estrella del norte.** Es lo que Carlos pidio. Los archivos son medios, no el fin.
- EVIDENCIA = archivos que se crean/editan (tecnico)
- CRITERIO = comportamiento que el usuario puede verificar (funcional)
Sin CRITERIO, el Gate falla. Sin Acceptance Gate que verifique el CRITERIO, la tarea NO esta completa.

---

## PASO 2 — MOSTRAR PLAN A CARLOS + COSTO + APROBAR (OBLIGATORIO)

Antes de avanzar a PASO 2.5 (Gate), presentar el plan completo a Carlos. Formato exacto:

```
=================================================================
PLAN: [nombre de la tarea]
PROYECTO: [proyecto]
WAVES: [N waves]
DURACION ESTIMADA: [X minutos]
COSTO ESTIMADO: Opus ~$X.XX + Workers $0 + Verifiers $0 = ~$X.XX
=================================================================

Wave 0 (si aplica — investigacion):
  - Worker 1: [que lee/investiga] → /tmp/wave0-*.txt
  - Worker 2: [que lee/investiga] → /tmp/wave0-*.txt

Wave 1 — [nombre] (paralelo):
  - Worker 1: ARCHIVO [/ruta/exacta] ACCION [editar|crear] CAMBIO [que cambia]
  - Worker 2: ARCHIVO [/ruta/exacta] ACCION [editar|crear] CAMBIO [que cambia]
  - Verifier: [comando de verificacion exacto]

Wave 2 — [nombre] (depende de Wave 1):
  - Worker 1: ARCHIVO [/ruta/exacta] CAMBIO [que cambia]
  - Verifier: [comando de verificacion exacto]

ARCHIVOS QUE SE TOCAN: [lista completa]
ROLLBACK: git reset --hard pre-[nombre-tarea]
ROLLBACK GRANULAR: git reset --hard wave-N-done  (cada wave verificada tiene tag)

CHECKS POST-EJECUCION:
  - Build: [comando]
  - Servicios afectados: [lista + health endpoint]
  - Test suite: [comando si aplica]

CRITERIO DE ACEPTACION:
  [comportamiento testeable que Carlos puede verificar — NO archivos, sino comportamiento]
  Ejemplo: "curl /api/historial devuelve array con campo periodo" / "boton azul aparece"

APROBACION REQUERIDA:
¿El CRITERIO describe exactamente lo que pediste? ¿Apruebas? (si / no / ajustar [que])
=================================================================
```

### Reglas de aprobacion

- Si Carlos dice "si", "ok", "hazlo", "adelante", "dale" → continuar PASO 2.5
- Si Carlos dice "ajustar X" → modificar plan y mostrar de nuevo
- Si Carlos dice "no" → abortar, borrar lock, reportar
- **Si plan tiene >50 workers O >5 waves → DOBLE aprobacion** (re-leer plan explicitamente)
- **Sin respuesta explicita → NO continuar. Esperar.**

### Costo estimator (formula)

```
Opus (arquitecto):  tokens_plan × $0.015/1K  ≈ $0.05-0.30 por plan
Workers (Kimi K2.6): $0 (CLIProxy gratis)
Verifiers (Gemini Flash): $0 (CLIProxy gratis)
TOTAL ~ $0.05 - $0.30 por plan tipico
```

---

## PASO 2.5 — GEMINI GATE (OBLIGATORIO — BLOQUEO DE DISPATCH)

**Sin Gate aprobado NO hay dispatch. Enforcement via wrapper.**

```bash
# Escribir plan completo a archivo temporal
cat > /tmp/plan-[task].txt <<'EOF'
PLAN: ...
TAREA: ...
MODELO: Arquitecto claude-opus-4-6. Workers kimi-k2.6 via CLIProxy. Verifiers gemini-2.5-flash via CLIProxy
BORIS: git pull origin main + git tag pre-[nombre]-[fecha]
VERIFICACION: ...
EVIDENCIA: ...
CRITERIO: [comportamiento testeable desde perspectiva del usuario — ej: "GET /api/historial devuelve array con campo periodo"]
EOF

# Ejecutar Gate (valida 7 etiquetas obligatorias con Gemini Flash)
/home/gestoria/scripts/gemini-gate-execute.sh [task_name] < /tmp/plan-[task].txt

# Exit 0 (PASS) → continua a PASO 3
# Exit 1 (FAIL) → re-hacer plan, max 2 reintentos
```

**Qué valida el Gate:**
- Presencia de las 7 etiquetas obligatorias (PLAN, TAREA, MODELO, BORIS, VERIFICACION, EVIDENCIA, CRITERIO)
- Cada etiqueta con contenido concreto (no vacia, no generico)
- CRITERIO debe describir comportamiento testeable desde perspectiva de usuario, no archivos

**Si FAIL 3 veces → PARAR. Escalar a Carlos.**

**Gate log** se escribe a `.brain/gate-log-[task].txt` con timestamp. El wrapper `mithos-dispatch-gated.sh` verifica este log antes de cada curl — si no existe o tiene >5min → `exit 1 GATE REQUIRED`.

**PROHIBIDO**: `curl localhost:18810/dispatch` directo. Si intentas bypassear el Gate, el trabajo se rechaza automaticamente (revisable en `.brain/dispatch-history.log`).

---

## PASO 3 — PARL SCORECARD (OBLIGATORIO antes de dispatch)

```
/sypnose-parl-score  [sobre el plan completo]
```

Gates que deben pasar:
- `r_parallel_pred >= 0.05` — hay paralelismo real
- `parallel_ratio >= 2.0` — al menos 2x mas tareas paralelas que seriales
- `concurrency_peak >= 2` — pico de 2+ workers simultaneos
- `r_finish_pred >= 0.9` — plan tiene alta probabilidad de terminar
- `critical_ratio <= 0.6` — no mas del 60% en cadena serial

Si PASS → `kb_save parl_scorecard.pre_exec` y proceder.
Si FAIL sin excepcion → NO despachar. Reagrupar tareas. Max 2 intentos. A la 3ra → escalar a Carlos.

Excepciones validas (documentar en el plan):
- `--skip-parl micro` para 1 sola accion
- `swarm_dispatch: true` para exploracion sin targets fijos

---

## PASO 4 — GIT PUNTO DE NO RETORNO

```bash
cd [proyecto]
git pull origin $(git branch --show-current)
git tag pre-[nombre-tarea]-$(date +%Y%m%d) -m "Punto de retorno antes de [tarea]"
git push origin pre-[nombre-tarea]-$(date +%Y%m%d)

# Update state
python3 -c "
import json
s = json.load(open('.brain/sypnose-state-[task].json'))
s['phase'] = 'executing'
s['pre_tag'] = 'pre-[nombre-tarea]-[fecha]'
json.dump(s, open('.brain/sypnose-state-[task].json','w'), indent=2)
"
```

Si el plan falla tarde → `git reset --hard pre-[nombre-tarea]-[fecha]`
Rollback granular → `git reset --hard wave-N-done` (tag creado tras cada wave verificada)

---

## PASO 5 — DISPATCH DIRECTO (sin Sonnet capataz)

El arquitecto hace dispatch directo a Mithos via wrapper. 1 curl por wave. Poll hasta workers_active=0. Commit entre waves.

### Dispatch + Poll + Commit por cada wave

```bash
TASK_NAME="[nombre-tarea]"
WAVE_NUM=1  # N de M

# 5.1 DISPATCH A — EXECUTORS CON BORIS ATOMICO
# Modelo: kimi-for-coding (DIRECTO — sin CLIProxy)
# Los workers se auto-verifican internamente (CLAUDE-executor.md tiene Boris Atomico)
# Cada worker reporta DONE: o FAILED: al terminar — NO necesitan verifier wave separada en tareas simples
cat > /tmp/wave-${WAVE_NUM}-exec.json <<'JSON_EOF'
{
  "description": "Wave N — [nombre] executors",
  "workspace": "/ruta/proyecto",
  "keep_workspace": true,
  "max_parallel": 300,
  "tasks": [
    {
      "profile": "executor",
      "description": "[INSTRUCCION EXACTA con CONTEXTO+ARCHIVO+ACCION+CAMBIO+VERIFICACION+SI FALLA]",
      "timeout_secs": 600,
      "model": "kimi-k2.6"
    }
  ]
}
JSON_EOF

# Dispatch via wrapper (Gate obligatorio)
DISPATCH_RESULT=$(/home/gestoria/scripts/mithos-dispatch-gated.sh ${TASK_NAME} /tmp/wave-${WAVE_NUM}-exec.json)
echo "$DISPATCH_RESULT"
PLAN_ID=$(echo "$DISPATCH_RESULT" | python3 -c "import sys,re; m=re.search(r'plan_id[\":\s]+([a-zA-Z0-9_-]+)', sys.stdin.read()); print(m.group(1) if m else '')" 2>/dev/null)
# Si GATE REQUIRED → volver a PASO 2.5

# 5.2 POLL — esperar workers (30s via CLIProxy)
for i in {1..40}; do
  sleep 30
  H=$(curl -s http://localhost:18810/health)
  ACTIVE=$(echo "$H" | python3 -c "import json,sys;print(json.load(sys.stdin)['workers_active'])")
  echo "[$i] active=$ACTIVE"
  if [ "$ACTIVE" = "0" ]; then break; fi
done
# TIME BUDGET: 20 min por wave. Si supera → investigar, preguntar a Carlos.

# 5.3 LEER OUTPUTS — verificar DONE/FAILED por worker
# Leer resultados via plan_id:
[ -n "$PLAN_ID" ] && curl -s http://localhost:18810/status/${PLAN_ID} | python3 -c "
import sys,json
data=json.load(sys.stdin)
for r in data.get('results',[]):
    status=r.get('status','?')
    tid=r.get('task_id','?')
    out=(r.get('output','') or '')[:200]
    print(f'[{status}] {tid}: {out}')
"
# Los workers con Boris Atomico reportan en su output:
#   DONE: Archivo: X | Cambio: Y | Verificacion: [output exacto]
#   FAILED: Intentos: 3 | Ultimo error: [output] | Estado: [que quedo hecho]
# Si TODOS dicen DONE → ir directo a 5.5 (sin verifier wave)
# Si ALGUNO dice FAILED → VER 5.3b antes de dispatch debugger
# Si tarea requiere build/E2E → dispatch verifier final (ver 5.4)
# NOTA RTK: Si RTK trunca output de curl (curl ... | wc -l devuelve numero menor al real),
# usar: curl ... -o /tmp/out.txt 2>/dev/null && wc -l /tmp/out.txt

# 5.3b WORKER FAILED → git diff ANTES de debugger (estado del archivo es desconocido)
# NUNCA mandar debugger sin saber en qué estado quedó el archivo
git -C [proyecto] diff --stat          # cuantos archivos cambiaron
git -C [proyecto] diff [archivo-fallido] | head -40   # que cambios hay
# ENTONCES dispatch debugger con contexto exacto: "El archivo tiene estos cambios parciales: [diff]"

# 5.4 VERIFIER REAL — conecta a la cosa real, no teatro
# Gemini Flash ejecuta el comando que demuestra que funciona segun el tipo:
#   BD tocada         → SQL query con SELECT que confirme cambios
#   Frontend tocado   → curl http://localhost:3000/ruta + grep contenido esperado
#   API tocada        → curl endpoint + assert response code + body
#   Archivo editado   → grep de la cadena esperada en el archivo
#   Docker tocado     → docker ps + curl health
#   Deploy            → curl publico + verificar status 200
# NO vale "el worker dice VERIFIED". Vale solo output REAL del sistema.
cat > /tmp/wave-${WAVE_NUM}-verify.json <<'JSON_EOF'
{
  "description": "Wave N — verifier real",
  "keep_workspace": true,
  "max_parallel": 1,
  "tasks": [
    {
      "profile": "verifier",
      "workspace": "/ruta/proyecto",
      "description": "Ejecuta EXACTAMENTE estos comandos y copia el output literal (no parafrasear):\n1. [comando 1: ej curl http://localhost:3000/api/foo]\n2. [comando 2: ej docker exec supabase-db psql -U postgres -c 'SELECT count(*) FROM bar']\n3. [comando 3: ej grep 'cadena esperada' /ruta/archivo]\n\nCopia output LITERAL. Luego reporta PASS si todos retornan lo esperado, FAIL si alguno no.",
      "timeout_secs": 300,
      "model": "gemini-2.5-flash"
    }
  ]
}
JSON_EOF

/home/gestoria/scripts/mithos-dispatch-gated.sh ${TASK_NAME}-verify /tmp/wave-${WAVE_NUM}-verify.json

for i in {1..20}; do
  sleep 30
  ACTIVE=$(curl -s http://localhost:18810/health | python3 -c "import json,sys;print(json.load(sys.stdin)['workers_active'])")
  [ "$ACTIVE" = "0" ] && break
done

# 5.5 CHECKPOINT (obligatorio antes de continuar)
# [ ] Workers: todos reportaron DONE (o verifier final: PASS)
# [ ] Build/lint: sin errores
# [ ] git diff: solo archivos esperados modificados

# 5.6 GIT commit + tag wave-N-done
cd [proyecto]
mkdir -p .brain
cat > .brain/wave-${WAVE_NUM}-status.md <<EOF
wave: ${WAVE_NUM}
timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)
workers: X exitosos, Y fallidos
archivos: [lista]
verificacion: PASS
EOF

git add [archivos especificos — NUNCA git add .]
git commit -m "[WAVE-${WAVE_NUM}] [descripcion]"
git tag wave-${WAVE_NUM}-done -m "Wave ${WAVE_NUM} verificada"

# 5.7 Actualizar state + progress
python3 -c "
import json
s = json.load(open('.brain/sypnose-state-${TASK_NAME}.json'))
s['waves_completed'] += 1
s['files_touched'] += [...]
s['commits'].append('$(git rev-parse HEAD)')
json.dump(s, open('.brain/sypnose-state-${TASK_NAME}.json','w'), indent=2)
"

cat > .brain/sypnose-progress.md <<EOF
WAVE: ${WAVE_NUM}/M completada
ESTADO: verificado
WORKERS: X exitosos, Y fallidos
COMMIT: $(git rev-parse --short HEAD)
EOF

# Repeat para siguiente wave (incrementar WAVE_NUM)
```

---

## CHECKPOINT ENTRE WAVES (REGLA DE HIERRO)

**NO pasar a Wave N+1 sin verificar Wave N.**

```
[ ] Workers: todos reportaron DONE (Boris Atomico) — o verifier final PASS si aplica
[ ] Build/lint check: [comando] → sin errores
[ ] git diff: solo archivos esperados modificados
[ ] git commit + git tag wave-N-done
[ ] state file actualizado
[ ] progress file actualizado
```

Si un worker reporta FAILED (agoto 3 intentos) → dispatch 1 debugger worker para ese archivo.
Si 3 waves fallan → PARAR. Escalar a Carlos con error exacto.

**Regla Boris Atomico para verifier wave:**
- 1-5 archivos, cambios simples (editar lineas) → NO verifier wave. Workers se auto-verifican.
- >5 archivos O build requerido O deploy → SI verifier final con build check.
- Siempre que se toque npm/package.json → verifier final con `npm run build`.

**Por que:** 27-Mar-2026, arquitecto GestoriaRD se salto verificacion. BD modificada sin deploy. SaaS caido. Horas de reparacion.

---

## PASO 6 — CIERRE + REPORTE ENRIQUECIDO

Al terminar TODAS las waves. No solo "done" — reporte con mejoras y descubrimientos.

### 6.0 ACCEPTANCE GATE (OBLIGATORIO — antes de declarar DONE)

**REGLA ORO de verificacion (Contabo v6.2)**: el verificador es Gemini Flash via dispatch, NUNCA un worker que dice "VERIFIED". El Acceptance Gate es comando REAL + output LITERAL:
- BD tocada → `docker exec supabase-db psql -U postgres -c 'SELECT ...'` + filas reales
- Frontend tocado → `curl -s http://localhost:3000/ruta` + grep contenido esperado + screenshot si aplica
- API tocada → `curl -s endpoint` + status + body
- Archivo → `grep 'cadena' /ruta/absoluta` con output literal
- Docker → `docker ps | grep nombre` + `curl health`
- Deploy → `curl publico` + status 200

Si el verificador no puede conectarse a la cosa real (filesystem aislado, sin red, sin psql), NO es verificador valido — dispatch otro con workspace/perms correctos.

**¿El resultado entrega lo que Carlos pidio?** No "funciona el codigo", sino "se comporta como fue pedido".

```bash
# Leer el CRITERIO del plan (escrito en PASO 1)
echo "CRITERIO: [copiar texto del CRITERIO]"

# Ejecutar la verificacion del CRITERIO — NO tsc, sino comportamiento real
# Ejemplos concretos:
#   Si Carlos pidio "historial con filtros" → curl -s /api/historial?periodo=2025 | python3 -c "import sys,json; d=json.load(sys.stdin); assert len(d)>0; print('OK:', len(d), 'rows')"
#   Si Carlos pidio "boton azul" → Chrome MCP screenshot → grep/visual
#   Si Carlos pidio "error 422 desaparece" → reproducir escenario original → confirmar 200/201
#   Si Carlos pidio "campo periodo en la tabla" → curl /api/... | grep "periodo"

# PASS → continuar a 6.1
# FAIL → NO declarar DONE. Identificar gap exacto. Volver a PASO 5 con corrección específica.
#         NUNCA declarar DONE con PENDIENTE sin aprobacion de Carlos.
```

**Regla anti-PENDIENTE:** Si algo queda incompleto, ANTES de declarar DONE:
1. Listar cada PENDIENTE con descripcion exacta
2. Dar razon por que no se hizo ahora
3. Esperar aprobacion EXPLICITA de Carlos para cada PENDIENTE
4. Solo ENTONCES hacer kb_save category=notification con DONE

Sin aprobacion de Carlos por cada PENDIENTE = tarea NO esta completa = NO hacer kb_save DONE.

### 6.1 Boris verify (OBLIGATORIO antes de declarar completado)

```
boris_verify(
  what_changed="[que cambio — min 20 chars]",
  how_verified="[comando exacto ejecutado — incluyendo CRITERIO del plan]",
  result="[output real copiado — min 15 chars]"
)
```

**Boris v6.1 simplificado**: el Acceptance Gate del PASO 6.0 es LA verificacion real (comando ejecutado + output literal). boris_verify MCP es OPCIONAL — si el MCP no escribe `.brain/last-verification.md`, NO reintentar: Write tool crea el archivo directamente con Estado: APROBADO + output literal del comando.

**Excepcion remote-only**: Si la tarea fue 100% GitHub API / curl remoto (sin commits locales), no hace falta `.brain/last-verification.md`. Usar `kb_save` con SHA GitHub + content-length como evidencia.

**HOOKS BLOQUEANTES en Contabo (eliminados v6.2)**: el PreToolUse:Bash `boris-verification-gate.sh` se retiro del `.claude/settings.json` porque disparaba falsos positivos con la frase "git commit" dentro de heredocs/descripciones. El verificador real es Gemini Flash + Acceptance Gate con output literal, no un hook de texto. Los hooks que SI se mantienen (no bloquean, solo ayudan): SessionStart, PreCompact, Stop, boris-protect-files (Edit|Write sobre archivos criticos).

**HOOK gate eliminado en Contabo**: el PreToolUse:Bash de `boris-verification-gate.sh` se retiro del `settings.json` (disparaba falsos positivos con la frase "git commit" en heredocs). El verificador real es Gemini Flash conectando a la cosa real (curl/SQL/browser), no un hook de texto.

### 6.2 Post-execution health check (auto-rollback si algo rompio)

```bash
# Servicios afectados siguen UP
for svc in [lista servicios]; do
  curl -sf http://127.0.0.1:[puerto]/health || {
    echo "ALERT: $svc CAIDO tras deploy"
    git reset --hard pre-[nombre-tarea]-[fecha]
    channel_publish channel=system-alerts message="ROLLBACK AUTO: [tarea] rompio $svc"
    exit 1
  }
done

# Build check final
[comando build] || { echo "BUILD FAIL"; exit 1; }
```

### 6.3 Git final + 2 memorias (LightRAG es automatico)

```bash
git push origin $(git branch --show-current)
git push origin pre-[nombre-tarea]-[fecha]

boris_register_done(task_name="[nombre]", verification_summary="[resumen]")

# .brain/history.md — registro permanente
cat >> .brain/history.md <<EOF

### [FECHA] — [Arquitecto] — [Descripcion corta]
**Estado**: Completado
**Archivos**: [lista]
**Cambios**: [resumen]
**Verificacion**: [que se probo con output]
**Mejoras encontradas**: [descubrimientos]
EOF

git add .brain/ && git commit -m "[BRAIN] wave-summary [fecha]" && git push
```

### 6.4 REPORTE ENRIQUECIDO — KB (memoria 1) + Memory Palace (memoria 2 — alimenta LightRAG auto)

```bash
# KB — notificacion al SM (OBLIGATORIO — sin esto el SM no sabe que terminaste)
kb_save \
  key=resultado-[arquitecto]-[nombre]-$(date +%Y%m%d) \
  category=notification \
  project=[proyecto] \
  value="
DONE: [que ejecutaste exactamente]
COMMITS: [hashes]
VERIFICADO: [que comprobaste — con output REAL copiado, no parafraseado]
WAVES: [N completadas de M total]
WORKERS: [total lanzados, exitosos, fallidos]

MEJORAS ENCONTRADAS: [bugs descubiertos, refactors obvios, riesgos]
INQUIETUDES: [que preocupa del estado actual]
SUGERENCIAS: [proximo paso recomendado con detalle]
APRENDIZAJES: [que errores se evitaron, que funciono nuevo]

COSTO REAL: [Opus tokens]
DURACION REAL: [minutos desde boris_start hasta aqui]
"

# Notificacion directa al SM
kb_save \
  key=notify-sm-[nombre]-$(date +%Y%m%d) \
  category=notification \
  project=[proyecto] \
  value="DONE: [nombre] | TO: sm-claude-web | FROM: [agente] | COMMIT: [hash] | RESUMEN: [1 linea]"

# Memory Palace — conocimiento semantico cross-project (LightRAG lo ingesta cada 4h auto)
curl -s -X POST http://localhost:18792/sypnose_add \
  -H "Content-Type: application/json" \
  -d '{"params":{"wing":"[proyecto]","room":"[tema]","content":"[que hiciste + resultado + mejoras encontradas]","summary":"[resumen corto]"}}'

# Error learning broadcast — si hubo errores durante el run
if [ "$ERRORES_ENCONTRADOS" ]; then
  channel_publish channel=errors-global message="LESSON [AREA] [proyecto]: [1-line summary del error + fix]"
fi
```

### 6.5 Auto-cleanup

```bash
rm -f /tmp/sypnose-execute-[proyecto].lock
rm -f /tmp/wave-*-exec.json /tmp/wave-*-verify.json
rm -f /tmp/plan-[task].txt
# state file se mantiene en .brain/ para auditoria
# gate-log se mantiene en .brain/ para auditoria
```

### 6.6 Reporte markdown final a Carlos (estructurado)

```markdown
## TAREA COMPLETADA: [nombre]

**Proyecto**: [proyecto]
**Duracion**: [X min]
**Costo real**: $[X.XX]
**Waves**: N/M completadas
**Workers**: X exitosos, Y fallidos

### Archivos modificados
- `/ruta/archivo1` — [que cambio]
- `/ruta/archivo2` — [que cambio]

### Commits
- `[hash1]` [WAVE-1] descripcion
- `[hash2]` [WAVE-2] descripcion

### Verificacion
[output real de tests/builds/curl]

### Mejoras encontradas
- [bug 1 descubierto]
- [refactor obvio detectado]
- [riesgo identificado]

### Inquietudes
- [que preocupa del estado actual]

### Sugerencias (proximo paso)
- [detalle concreto de que harias siguiente]

### Aprendizajes de este run
- [que funciono nuevo]
- [que errores se evitaron]
```

---

## REGISTRO DE ERRORES GLOBAL CROSS-SERVER (Contabo + Sypnose)

Todo error nuevo en CUALQUIER agente, en CUALQUIER servidor, se graba en un SOLO lugar compartido para que ningun arquitecto lo repita.

### 3 sitios de grabado (todos obligatorios):

1. **KB (Knowledge Hub)** — cross-project index:
```
kb_save
  key=error-[AREA]-[servidor]-YYYYMMDD
  category=lesson
  project=global
  value="[formato abajo]"
```

2. **Memory Palace** — semantic search cross-corpus:
```bash
curl -s -X POST http://localhost:18792/sypnose_add -H 'Content-Type: application/json' -d '{"params":{"wing":"global","room":"errores-aprendidos","content":"[formato abajo]","summary":"[1 linea del error]"}}'
```

3. **LightRAG** — ingesta auto cada 4h desde Memory Palace.

### Formato obligatorio:
```
AREA: frontend | bd | workers | infra | api | hooks | deployment
SERVIDOR: contabo | sypnose | ambos
ERROR: [output literal copiado, no parafraseado]
RAIZ: [por que paso — analisis de causa real]
FIX: [comando/cambio concreto que lo resolvio]
EVITAR: [regla 1 linea para no repetir]
DESCUBIERTO: YYYY-MM-DD por [arquitecto]
```

### Consulta OBLIGATORIA antes de cada PASO 0.3:
```bash
kb_search "category=lesson project=global"
curl -s -X POST http://localhost:18792/sypnose_search -H 'Content-Type: application/json' -d '{"params":{"query":"[tema]"}}'
```
Si encuentras error aplicable → leer FIX antes de seguir. Error repetido = rechazo automatico.

---

## PROTOCOLO DE ERRORES

### Guardar error cuando algo falla (OBLIGATORIO)

```bash
kb_save \
  key=lesson-[AREA]-[proyecto]-$(date +%Y%m%d) \
  category=lesson \
  project=[proyecto] \
  value="
AREA: frontend | bd | scripts | infra | api | workers
ERROR: [output exacto — copiar, no parafrasear]
CAUSA: [raiz real, no sintoma]
FIX: [comando/cambio exacto que lo resolvio]
EVITAR: [regla concreta para no repetirlo]
ARCHIVOS: [rutas completas]
"

# Broadcast global — todos los arquitectos aprenden en tiempo real
channel_publish channel=errors-global message="LESSON [AREA] [proyecto]: [1-line fix]"
```

### Areas y cuando guardar

| Area | Guardar cuando falla... |
|---|---|
| `frontend` | worker edita .tsx/.jsx/.html/.css y build rompe o UI no muestra |
| `bd` | migracion falla, SELECT da datos incorrectos, schema no existe |
| `scripts` | bash -n falla, cron no corre, systemd unit error |
| `infra` | docker build falla, container no arranca, UFW bloquea trafico |
| `api` | endpoint retorna 4xx/5xx, RPyC no conecta, timeout |
| `workers` | worker dice "no changes needed", dispatch JSON invalido, timeout |

### Reportar error — solo 2 valores (PASS/FAIL)

**Verifier** → `PASS: [output]` | `FAIL: [output exacto error]`
**Arquitecto** → `AREA: [...] | STATUS: PASS|FAIL | ERROR: [output real]`

### Si error es URGENTE (servicio caido, BD corrupta, deploy roto)

```bash
channel_publish channel=system-alerts message="ERROR [AREA] [proyecto]: [descripcion 1 linea]"
```

---

## LEY DE EVIDENCIA (28-Mar-2026)

| Cambio | Evidencia obligatoria |
|---|---|
| Config/scripts | Output de que el servicio corre |
| SaaS (codigo) | curl/Chrome → rutas afectadas funcionan |
| Seguridad | curl con/sin auth, RLS con/sin permisos |
| Base de datos | SELECT confirma datos correctos |
| Docker/deploy | docker ps + curl health |
| API endpoint | curl → response con status code |

**Sin evidencia no hay trabajo.** Punto.

---

## TRIAGE DE RESPUESTAS (del arquitecto a Carlos)

- **URGENTE** → crear plan nuevo inmediato, informar a Carlos
- **MEJORA** → crear plan prioridad media
- **DECISION** → presentar opciones a Carlos, NO crear plan sin su OK
- **INFORMATIVO** → resumir a Carlos en 3 lineas, archivar en KB

---

## MODELOS DISPONIBLES (v6 — ACTIVOS)

### Workers (ejecutan codigo) — via CLIProxy :8317

| Modelo | ID dispatch | Uso |
|---|---|---|
| **Kimi K2.6** | `kimi-k2.6` | Workers complejos (editor de codigo). max_tokens >= 4096 |

### Gate y Verificadores — via CLIProxy :8317

| Modelo | ID | Uso |
|---|---|---|
| **Gemini 2.5 Flash** | `gemini-2.5-flash` | Gate + Verifiers finales + workers rapidos no-thinking. max_tokens >= 500 |

### NO USAR (DEPRECATED — desde 23-Abr-2026)
Todos los siguientes siguen tecnicamente en CLIProxy `config.yaml` por compatibilidad de otros proyectos legacy, pero **no se usan** en sypnose-execute:
- `kimi-k2` (sin .6), `kimi-k2-0905`, `kimi-for-coding` directo
- `gemini-2.5-pro`, `gemini-2.5-flash-lite`, `gemini-2.0-*`, `gemini-3-*`, `gemini-web`
- `claude-haiku-4-5`, `claude-sonnet-4-6`, `claude-sonnet-4-5`, `claude-3-5-haiku`, `claude-3-7-sonnet`
- `deepseek-v3.2`, `deepseek-r1`, `cerebras-*`, `qwen*`, `gpt-oss-*`, `moonshotai/*`, `llama-*`

Si un dispatch de Mithos retorna con `model_used` distinto a `kimi-k2.6` o `gemini-2.5-flash` → es bug de Mithos ignorando el `"model"` specified. Workaround: hacer `curl` directo a CLIProxy `:8317` con el modelo correcto, no dispatch.

---

## PERFILES DE WORKER

| Profile | Usa cuando | Modelo |
|---|---|---|
| `executor` | Comando bash, crear archivo, cambio puntual | `kimi-k2.6` |
| `executor-pro` | Editar codigo con contexto amplio | `kimi-k2.6` |
| `researcher` | Leer, investigar, documentar /tmp/ | `kimi-k2.6` |
| `verifier` | PASS/FAIL con output real (solo wave final) | `gemini-2.5-flash` |
| `debugger` | Diagnosticar bug, analizar logs | `kimi-k2.6` |

---

## COSTOS

| Capa | Costo | Hace |
|---|---|---|
| Arquitecto (Opus) | $0.015/1K tokens | Planifica + dispatch directo + verifica |
| Workers kimi-k2.6 | $0 | Ejecutan + auto-verifican (Boris Atomico) |
| Verifier final gemini-2.5-flash | $0 | PASS/FAIL solo en waves que necesitan build/E2E/CRITERIO |

Plan tipico: $0.05 - $0.30 total.
**Mejora vs v4**: eliminadas verifier waves intermedias para tareas simples → ~30-50% menos round trips.
**Mejora v6 vs v5**: Gemini Flash activo para verifiers → respuestas mas rapidas y precisas en PASS/FAIL.

---

## RECOVERY (--resume)

Si el contexto se resetea durante ejecucion:

```bash
/sypnose-execute --resume [task-name]
```

Lee `.brain/sypnose-state-[task].json`, detecta wave actual, continua desde ahi.

Tambien sirve:
- `cat .brain/sypnose-progress.md` — estado human-readable
- `git log --oneline` — ver que waves se commitearon
- `git tag | grep wave-` — ver rollback points disponibles

---

## EJEMPLO 1 — TAREA SIMPLE (info suficiente)

Carlos: "cambia timeout mt5_http_server.py de 30 a 60"

Arquitecto:
1. Pre-flight health check → OK
2. Lock + `boris_start_task` + git tag
3. Plan al Carlos:
   ```
   PLAN: mt5-timeout-230426
   WAVES: 1 (micro)
   COSTO: ~$0.05
   Wave 1: worker Kimi K2.6 edita /home/gestoria/IATRADER-RUST/bridge/mt5_http_server.py
     CAMBIO: 'timeout=30' → 'timeout=60'
     VERIFICACION: grep 'timeout=60' archivo && echo OK (verifier Gemini Flash)
   ROLLBACK: git reset --hard pre-mt5-timeout-230426
   ¿Apruebas? (si/no/ajustar)
   ```
4. Carlos: "si"
5. Gemini Gate: echo plan | gemini-gate-execute.sh → PASS
6. `--skip-parl micro`, git tag
7. Arquitecto curl mithos-dispatch-gated.sh → 1 worker + 1 verifier
8. Poll, git commit, boris_verify, post-health, push, kb_save, Memory Palace, reporte

---

## EJEMPLO 2 — TAREA CON INVESTIGACION (info insuficiente)

Carlos: "arregla lo que este roto en el servidor"

Arquitecto:
1. Pre-flight → OK
2. Lock + boris_start_task
3. Wave 0 planificada: 5 researchers Kimi K2.6
4. Plan al Carlos:
   ```
   PLAN: server-triage-230426
   WAVES: 2 (investigar + arreglar)
   Wave 0: 5 researchers Kimi K2.6 en paralelo
     - curl health todos servicios → /tmp/wave0-health.txt
     - docker ps → /tmp/wave0-docker.txt
     - systemctl failed → /tmp/wave0-systemd.txt
     - df+free → /tmp/wave0-resources.txt
     - journalctl err → /tmp/wave0-errors.txt
   Wave 1: depende de Wave 0 — plan EXACTO se define tras Wave 0
   ¿Apruebas Wave 0? (Wave 1 aprobaras despues)
   ```
5. Carlos: "si"
6. Gate Wave 0 → PASS
7. Dispatch directo 5 workers researcher → poll → leer /tmp/wave0-*.txt
8. Arquitecto identifica qué esta roto
9. Plan Wave 1 a Carlos con instrucciones exactas
10. Gate Wave 1 → PASS → dispatch executors + verifiers → commit
11. Cierre con reporte enriquecido

---

## EJEMPLO 3 — TAREA MULTI-WAVE CON DEPENDENCIAS

Carlos: "migra la tabla users de schema public a schema auth y actualiza los endpoints"

Arquitecto:
1. Pre-flight + Lock + Boris
2. Plan:
   ```
   PLAN: users-schema-migration-230426
   WAVES: 3
   Wave 1 (BD): migracion SQL — depende de nada
   Wave 2 (API): actualiza 5 endpoints — depende de Wave 1
   Wave 3 (test): corre suite completa — depende de Wave 2
   COSTO: ~$0.25
   ROLLBACK: git reset --hard pre-users-schema + migracion inversa
   ```
3. Carlos aprueba
4. 3 Gates secuenciales (1 por wave, cada uno antes de dispatch)
5. 3 dispatches directos secuenciales (arquitecto, sin Sonnet)
6. Cierre con reporte de migracion + performance + sugerencias

---

## ERRORES COMUNES

| Error | Fix |
|---|---|
| Arquitecto hace grep/curl para investigar | NO. Wave 0 con researcher workers |
| Arquitecto edita archivos directamente | NO. Worker executor con instruccion exacta |
| `curl localhost:18810/dispatch` directo | PROHIBIDO. Usar `mithos-dispatch-gated.sh` |
| Worker "no changes needed" | Prompt vago. Dar linea exacta y cambio exacto |
| Worker pregunta en vez de ejecutar | CLAUDE-executor.md incorrecto en workspace |
| depends_on con strings | Mithos NO acepta strings, solo UUIDs. 2 dispatches separados |
| JSON con comillas en bash | Escribir /tmp/file.json, `curl -d @/tmp/file.json` |
| workers_active no baja a 0 | Poll cada 30-45s, timeout 600s/worker |
| Wave falla 3 veces | PARAR. No improvisar. Escalar a Carlos |
| Lock file huerfano | Verificar PID vivo con `kill -0 $PID` |
| State file corrupto | Leer last valid commit y reconstruir desde git |
| Gate FAIL repetido | Re-hacer plan con 6 etiquetas concretas, max 3 intentos |

---

## ANTI-PATRONES (PROHIBIDO)

- Dispatch sin Gemini Gate PASS (bypass del wrapper)
- Usar modelos fuera de kimi-k2.6 / gemini-2.5-flash sin justificar
- Invocar Agent(sonnet) como capataz (eliminado en v4)
- Dispatch sin mostrar plan a Carlos
- Dispatch sin aprobacion explicita ("si/ok/hazlo")
- Saltar pre-flight sin --force
- Workers editando mismo archivo (colision)
- Rehacer wave entera cuando 1 worker falla (usar debugger worker)
- "Ya lo hice" sin kb_save resultado
- Commit sin boris_verify
- git push sin post-health check
- Tocar .env (hook bloquea, exit 2)
- rm -rf, sudo reboot (deny en permissions)

---

## REGLA DE MEJORA (siempre al terminar)

Si durante el run descubriste algo util sobre el skill:

```bash
kb_save \
  key=skill-improvement-sypnose-execute-$(date +%Y%m%d) \
  category=skill-improvement \
  project=sypnose \
  value="
FRICCION: [que fue dificil o confuso]
SUGERENCIA: [como mejorar el skill proxima version]
EJEMPLO: [caso concreto donde el skill fallo o sobro]
"
```

El SM revisa `category=skill-improvement` para evolucionar este skill.

---

## DEPENDENCIAS DECLARADAS

Este skill requiere:
- **Skills**: `boris` o `boris-workflow`, `karpathy-guidelines`, `sypnose-parl-score`
- **MCPs**: `knowledge-hub` (kb_*), `sypnose-memory` (sypnose_*), `boris` (boris_*)
- **Servicios**: Mithos :18810, KB :18791, Memory Palace :18792
- **CLIProxy :8317**: REQUERIDO para todos los workers y verifiers. `CLIPROXY_BASE=http://localhost:8317/v1` en mithos-dispatch.service. Clave: `sk-GazR6oQwVsbxdaMK5PE_Ht-88lUn3IALdwtwyZg6eWo`
- **Kimi K2.6 (workers)**: accesible via CLIProxy como `kimi-k2.6`. Kimi API key configurada en CLIProxy config.yaml.
- **Gemini Flash (gate+verifiers)**: accesible via CLIProxy como `gemini-2.5-flash`. Proxy Cloud Run configurado en CLIProxy gcp-gemini provider.
- **Scripts**: `/home/gestoria/scripts/gemini-gate-execute.sh`, `/home/gestoria/scripts/mithos-dispatch-gated.sh`
- **Herramientas**: git, curl, python3, bash, jq

Si falta cualquiera → skill aborta en pre-flight con mensaje exacto.

---

## RESUMEN VISUAL DEL FLUJO v6 COMPLETO

```
/sypnose-execute [tarea]
  |
  v
PASO -1: Pre-flight (Mithos, KB, Palace, Kimi API directa, scripts gate+wrapper, git, disk, ram)
  |
  v
PASO 0: Lock + boris_start + errores previos + 2 memorias + state file
  |
  v
PASO 1: Planificar waves (instrucciones EXACTAS, anti-colision, file_map, 7 etiquetas)
  |
  v
PASO 2: Mostrar plan + costo a Carlos → APROBACION EXPLICITA
  |                                              |
  v (si)                                     v (no/ajustar)
PASO 2.5: GEMINI GATE (7 etiquetas)        replanificar o abortar
  |                                              |
  v (PASS)                                  v (FAIL, max 3 intentos)
PASO 3: PARL Scorecard                     re-hacer plan o escalar
  |
  v (PASS)
PASO 4: git tag pre-tarea + state persist
  |
  v
PASO 5: DISPATCH DIRECTO (sin Sonnet capataz)
  |
  v (por cada wave)
  mithos-dispatch-gated.sh [task] [exec.json]  → workers kimi-k2.6 via CLIProxy (Boris Atomico)
  POLL hasta workers_active=0 (poll cada 30s)
  Leer DONE/FAILED por worker
  [SOLO si build/E2E requerido] mithos-dispatch-gated.sh [task] [verify.json] → verifier gemini-2.5-flash
  CHECKPOINT → git commit + tag wave-N-done
  Update state + progress files
  |
  v (repeat hasta ultima wave)
  |
  v
PASO 6.0: ACCEPTANCE GATE — verificar CRITERIO del plan (comportamiento real, no tsc)
  |
  v (PASS)
PASO 6.1-6.5: boris_verify + post-health + push + 2 memorias (KB+Palace, LightRAG auto)
              + reporte enriquecido (mejoras + inquietudes + sugerencias)
              + auto-cleanup (lock, /tmp/*.json, plan.txt)
  |
  v
REPORTE MARKDOWN FINAL A CARLOS
```

Fin v6.
