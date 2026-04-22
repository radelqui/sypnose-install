---
name: sypnose-execute
description: Arsenal completo Sypnose v2 — el UNICO comando que un arquitecto necesita. Incluye Karpathy, Boris, pre-flight, planificacion, aprobacion de Carlos, PARL, git rollback, dispatch Sonnets+Workers+Verifiers, 2 memorias (KB+Palace) con LightRAG automatico, reporte final con mejoras/inquietudes/sugerencias. Cualquier persona del mundo puede ejecutarlo.
user_invocable: true
---

# /sypnose-execute [tarea | plan.md] [--flags]

Skill autocontenido. El arquitecto invoca este comando y tiene TODO lo que necesita: principios, flujo, dispatch, memorias, git, reporte. Cualquier colaborador del mundo puede usarlo sin leer otros archivos.

**Flags disponibles:**
- `--dry-run` → muestra plan, costo, PARL, pero NO despacha
- `--resume [task-name]` → retoma una tarea interrumpida desde state file
- `--skip-parl micro` → para tarea trivial de 1 solo paso
- `--force` → salta pre-flight health check (NO recomendado)

---

## PRINCIPIOS DE EJECUCION (Karpathy — LEER ANTES DE ACTUAR)

**1. Think Before Coding** — No asumir. Leer lo que existe antes de cambiar. Si hay duda, Wave 0 researcher.
**2. Simplicity First** — Minimo codigo que resuelve el problema. Sin features extra, sin abstracciones prematuras.
**3. Surgical Changes** — Tocar solo lo necesario. 1 worker = 1 archivo. No "mejorar" codigo adyacente.
**4. Goal-Driven** — Definir criterio de exito ANTES de despachar. No "deberia funcionar" — verificar con output real.
**5. Check Errors First** — Antes de cada wave, consultar `kb_search category=lesson project=[proyecto]`. Error repetido = trabajo rechazado.

---

## ARQUITECTURA — PIRAMIDE 4 CAPAS

```
ARQUITECTO (Opus) — planifica waves, escribe instrucciones EXACTAS, valida final
  └→ SONNET CAPATAZ (Agent tool, 1-5 paralelo) — curl dispatch, poll, git commit
       └→ WORKERS KIMI K2 (Mithos :18810, 10-30 por wave) — ejecutan 1 tarea atomica
            └→ VERIFICADORES (flash-lite, 1 por worker) — PASS/FAIL con output real
```

**Capacidad**: 5 Sonnets × 30 workers = 150 simultaneos. Recomendado: 8-30 por dispatch.
**Regla de oro**: El arquitecto NUNCA ejecuta codigo. Los workers hacen TODO.

---

## PASO -1 — PRE-FLIGHT HEALTH CHECK (automatico, antes de TODO)

Verificar que la infra esta viva. Si algo cae, PARAR — no trabajar sobre infra rota.

```bash
# Mithos (workers)
curl -sf http://localhost:18810/health | grep -q '"status":"ok"' || { echo "MITHOS DOWN"; exit 1; }

# KB (memoria 1)
curl -sf http://localhost:18791/health || { echo "KB DOWN"; exit 1; }

# Memory Palace (memoria 2, alimenta LightRAG automaticamente via cron 4h)
curl -sf http://localhost:18792/health || { echo "PALACE DOWN"; exit 1; }

# LightRAG (memoria 3, transparente — solo validar que MCP SSE responde)
curl -sf http://localhost:18794/health | grep -q '"status":"ok"' || { echo "LIGHTRAG DOWN"; exit 1; }

# Git pull funciona
cd [proyecto] && git pull origin $(git branch --show-current) || { echo "GIT DOWN"; exit 1; }

# Recursos: disco > 5GB, RAM < 85%
df -h / | awk 'NR==2 {gsub(/%/,"",$5); if($5>90) {print "DISK FULL"; exit 1}}'
free | awk 'NR==2 {if($3/$2*100 > 85) {print "RAM HIGH"; exit 1}}'
```

Si `--force` → saltar. Si algo cae sin `--force` → abortar con mensaje exacto de que esta abajo.

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

Si hay error que aplica a tu tarea -> leer el FIX antes de continuar. Error repetido = rechazo automatico.

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

Si contexto se resetea -> `/sypnose-execute --resume [task]` lee este JSON y retoma.

---

## PASO 1 — PLANIFICAR WAVES (el trabajo real del arquitecto)

El arquitecto convierte cada accion en instrucciones EXACTAS para workers.

### Regla de planificacion

| Carlos dice | El arquitecto hace |
|---|---|
| "arregla X" | Wave 0 researcher -> Wave 1 executor con cambio exacto |
| "implementa Y" | Divide en archivos, 1 worker por archivo, instrucciones line-by-line |
| "investiga Z" | Wave researcher -> resultados en /tmp/ -> arquitecto lee -> Wave executor |
| tarea trivial 1 paso | `--skip-parl micro` + 1 worker directo |

### Formato de instruccion de worker (OBLIGATORIO — 90% del exito)

```
CONTEXTO: [proyecto], [que estamos haciendo y por que]
ARCHIVO: /ruta/exacta/al/archivo.py
ACCION: editar | crear | ejecutar
CAMBIO: linea 45, cambia `return x*2` por `return x*3`
  (o si es crear: contenido completo del archivo)
VERIFICACION: python3 -c "from archivo import func; assert func(2)==6; print('OK')"
SI FALLA: reportar error exacto, NO improvisar cambios adicionales
```

**PROHIBIDO en prompts de workers:**
- "Mejora el codigo" (subjetivo)
- "Implementa la feature" (vago)
- "Revisa y arregla" (sin target)
- Dar mas de 1 tarea por worker

### Anti-colision (REGLA ABSOLUTA)

1 archivo = 1 worker. NUNCA 2 workers sobre el mismo archivo. Antes de dispatch, crear file_map:

```
worker-1 -> /src/api/auth.ts
worker-2 -> /src/api/users.ts
worker-3 -> /src/db/schema.sql
```

Si 2 tareas necesitan el mismo archivo -> waves diferentes (Wave 1 lo crea, Wave 2 lo edita).

### 6 etiquetas obligatorias del plan (Gemini Gate las valida)

```
PLAN: [descripcion en una linea]
TAREA: [que debe ejecutar, concreto]
MODELO: Arquitecto claude-opus-4-6. Capataz claude-sonnet-4-6. Workers openai/kimi-k2. Verifiers openai/gemini-2.5-flash-lite
BORIS: git pull origin main + git tag pre-[nombre]-[fecha]
VERIFICACION: [comando bash concreto por wave]
EVIDENCIA: [que archivos/outputs deben existir al terminar]
```

---

## PASO 2 — MOSTRAR PLAN A CARLOS + COSTO + APROBAR (OBLIGATORIO)

Antes de lanzar NINGUN Sonnet, presentar el plan completo. Formato exacto:

```
=================================================================
PLAN: [nombre de la tarea]
PROYECTO: [proyecto]
WAVES: [N waves]
DURACION ESTIMADA: [X minutos]
COSTO ESTIMADO: Opus ~$X.XX + Sonnet ~$X.XX + Workers $0 + Verifiers $0 = ~$X.XX
=================================================================

Wave 0 (si aplica — investigacion):
  - Worker 1: [que lee/investiga] -> /tmp/wave0-*.txt
  - Worker 2: [que lee/investiga] -> /tmp/wave0-*.txt

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

APROBACION REQUERIDA:
¿Apruebas este plan? (si / no / ajustar [que])
=================================================================
```

### Reglas de aprobacion

- Si Carlos dice "si", "ok", "hazlo", "adelante", "dale" -> continuar PASO 3
- Si Carlos dice "ajustar X" -> modificar plan y mostrar de nuevo
- Si Carlos dice "no" -> abortar, borrar lock, reportar
- **Si plan tiene >50 workers O >5 waves -> DOBLE aprobacion** (re-leer plan explicitamente)
- **Sin respuesta explicita -> NO dispatch. Esperar.**

### Costo estimator (formula)

```
Opus (arquitecto):  tokens_plan × $0.015/1K  ≈ $0.05-0.30 por plan
Sonnet (capataces): tokens × $0.003/1K × N_waves  ≈ $0.10-1.00
Workers (Kimi):     $0 (CLIProxy gratis)
Verifiers:          $0 (gemini-flash-lite gratis)
TOTAL ~ $0.20 - $1.50 por plan tipico
```

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

Si PASS -> `kb_save parl_scorecard.pre_exec` y proceder.
Si FAIL sin excepcion -> NO despachar. Reagrupar tareas. Max 2 intentos. A la 3ra -> escalar a Carlos.

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

Si el plan falla tarde -> `git reset --hard pre-[nombre-tarea]-[fecha]`
Rollback granular -> `git reset --hard wave-N-done` (tag creado tras cada wave verificada)

---

## PASO 5 — LANZAR SONNETS CAPATACES

El arquitecto lanza 1 `Agent(sonnet)` por wave. Si waves independientes -> paralelo.

```
Agent(
  subagent_type="general-purpose",
  model="sonnet",
  prompt="[TEMPLATE SONNET — ver abajo]"
)
```

**NUNCA opus para Sonnets. SIEMPRE sonnet.**
**El arquitecto NO hace curl. Los Sonnets hacen curl.**

### TEMPLATE SONNET CAPATAZ (copiar tal cual al Agent)

```
Eres Sonnet capataz de Wave N de M. Tu unico trabajo: curl a Mithos + git. NADA MAS.
NO leas archivos. NO investigues. NO edites nada tu mismo. SOLO despacha y reporta.

WORKSPACE: /ruta/del/proyecto
TASK_NAME: [nombre-tarea]
STATE_FILE: .brain/sypnose-state-[task].json
DESCRIPCION DE ESTA WAVE: [que hace]

=== DISPATCH A — EXECUTORS ===
Escribe /tmp/wave-N-exec.json con:
{
  "description": "Wave N — [nombre] executors",
  "workspace": "/ruta/proyecto",
  "keep_workspace": true,
  "max_parallel": 30,
  "tasks": [
    {
      "profile": "executor",
      "description": "[INSTRUCCION EXACTA con CONTEXTO+ARCHIVO+ACCION+CAMBIO+VERIFICACION+SI FALLA]",
      "timeout_secs": 600,
      "model": "openai/kimi-k2"
    }
  ]
}

Ejecuta:
curl -s -X POST http://localhost:18810/dispatch -H "Content-Type: application/json" -d @/tmp/wave-N-exec.json

=== POLL A ===
Ejecuta cada 30-45s hasta workers_active=0:
curl -s http://localhost:18810/health

TIME BUDGET: 20 min por wave. Si supera -> reportar al arquitecto, preguntar que hacer.

=== DISPATCH B — VERIFIERS ===
Escribe /tmp/wave-N-verify.json con:
{
  "description": "Wave N — [nombre] verifiers",
  "workspace": "/ruta/proyecto",
  "keep_workspace": true,
  "max_parallel": 30,
  "tasks": [
    {
      "profile": "verifier",
      "description": "Verifica Wave N: [ls archivos], [cat archivo | grep cambio], [build cmd]. Reporta PASS o FAIL con output exacto copiado.",
      "timeout_secs": 120,
      "model": "openai/gemini-2.5-flash-lite"
    }
  ]
}

curl -s -X POST http://localhost:18810/dispatch -H "Content-Type: application/json" -d @/tmp/wave-N-verify.json

=== POLL B ===
curl -s http://localhost:18810/health hasta workers_active=0.

=== CHECKPOINT (obligatorio antes de continuar) ===
[ ] Verifiers: PASS en todos
[ ] Build/lint: sin errores
[ ] git diff: solo archivos esperados modificados

=== GIT (solo si verifiers dicen PASS) ===
cd /ruta/proyecto
mkdir -p .brain
cat > .brain/wave-N-status.md << EOF
wave: N
timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)
workers: X exitosos, Y fallidos
archivos: [lista]
verificacion: PASS
EOF

git add [archivos especificos — NUNCA git add .]
git commit -m "[WAVE-N] [descripcion]"

# ROLLBACK GRANULAR: tag tras cada wave verificada
git tag wave-N-done -m "Wave N verificada"

=== ACTUALIZAR STATE ===
python3 -c "
import json
s = json.load(open('.brain/sypnose-state-[task].json'))
s['waves_completed'] += 1
s['files_touched'] += [...]
s['commits'].append('$(git rev-parse HEAD)')
json.dump(s, open('.brain/sypnose-state-[task].json','w'), indent=2)
"

=== ACTUALIZAR PROGRESS FILE (visible a Carlos sin preguntar) ===
cat > .brain/sypnose-progress.md << EOF
WAVE: N/M completada
ESTADO: verificado
WORKERS: X exitosos, Y fallidos
ARCHIVOS: [lista]
COMMIT: [hash]
ETA siguiente wave: ~[Xmin]
EOF

=== REPORTE AL ARQUITECTO ===
WAVE: N de M
STATUS: done | failed | partial
WORKERS: X exitosos, Y fallidos
ARCHIVOS: [lista de archivos creados/editados]
VERIFICACION: [output exacto de los verifiers]
ERRORES: [si hay, con output exacto]
COMMITS: [hash]
SIGUIENTE: [Wave N+1 o "plan completado"]
```

---

## CHECKPOINT ENTRE WAVES (REGLA DE HIERRO)

**NO pasar a Wave N+1 sin verificar Wave N.**

```
[ ] Verifiers: PASS en todos los workers
[ ] Build/lint check: [comando] -> sin errores
[ ] git diff: solo archivos esperados modificados
[ ] git commit + git tag wave-N-done
[ ] state file actualizado
[ ] progress file actualizado
```

Si un worker falla -> Sonnet despacha 1 debugger worker (NO rehace la wave).
Si 3 waves fallan -> PARAR. Escalar a Carlos con error exacto.

**Por que:** 27-Mar-2026, arquitecto GestoriaRD se salto verificacion. BD modificada sin deploy. SaaS caido. Horas de reparacion. Regla dura desde entonces.

---

## PASO 6 — CIERRE + REPORTE ENRIQUECIDO (fusionado de /sypnose-create-plan)

Al terminar TODAS las waves. No solo "done" — reporte con mejoras y descubrimientos.

### 6.1 Boris verify (OBLIGATORIO antes de declarar completado)

```
boris_verify(
  what_changed="[que cambio — min 20 chars]",
  how_verified="[comando exacto ejecutado]",
  result="[output real copiado — min 15 chars]"
)
```

Sin boris_verify -> hook bloquea git commit.

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
# Push del codigo
git push origin $(git branch --show-current)

# Push del tag de inicio (por si falla la proxima sesion)
git push origin pre-[nombre-tarea]-[fecha]

# boris_register_done
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

COSTO REAL: [Opus + Sonnet tokens]
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
# state file se mantiene en .brain/ para auditoria
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

## PROTOCOLO DE ERRORES (fusionado de /sypnose-create-plan)

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

**Verifier** -> `PASS: [output]` | `FAIL: [output exacto error]`
**Sonnet capataz** -> `WAVE: N | STATUS: done|failed | FALLO: [output exacto]`
**Arquitecto** -> `AREA: [...] | STATUS: PASS|FAIL | ERROR: [output real]`

### Si error es URGENTE (servicio caido, BD corrupta, deploy roto)

```bash
channel_publish channel=system-alerts message="ERROR [AREA] [proyecto]: [descripcion 1 linea]"
```

---

## LEY DE EVIDENCIA (28-Mar-2026)

| Cambio | Evidencia obligatoria |
|---|---|
| Config/scripts | Output de que el servicio corre |
| SaaS (codigo) | curl/Chrome -> rutas afectadas funcionan |
| Seguridad | curl con/sin auth, RLS con/sin permisos |
| Base de datos | SELECT confirma datos correctos |
| Docker/deploy | docker ps + curl health |
| API endpoint | curl -> response con status code |

**Sin evidencia no hay trabajo.** Punto.

---

## TRIAGE DE RESPUESTAS (del arquitecto a Carlos)

- **URGENTE** -> crear plan nuevo inmediato, informar a Carlos
- **MEJORA** -> crear plan prioridad media
- **DECISION** -> presentar opciones a Carlos, NO crear plan sin su OK
- **INFORMATIVO** -> resumir a Carlos en 3 lineas, archivar en KB

---

## MODELOS DISPONIBLES

### Workers (ejecutan codigo) — prefijo `openai/` OBLIGATORIO

| Modelo | ID dispatch | Notas |
|---|---|---|
| Kimi K2 (primario) | `openai/kimi-k2` | $0, 30+ paralelo |
| Kimi K2-0905 | `openai/kimi-k2-0905` | $0, backup |
| Kimi K2.6 | `openai/kimi-k2.6` | $0, fallback |
| DeepSeek V3 | `openai/deepseek-v3` | $0, fallback final |

Fallback: kimi-k2 -> kimi-k2-0905 -> kimi-k2.6 -> deepseek-v3

### Verificadores

| Modelo | ID | Velocidad |
|---|---|---|
| Gemini Flash Lite (primario) | `openai/gemini-2.5-flash-lite` | ~2s, $0 |
| Cerebras Llama 8B | `openai/cerebras-llama-8b` | ~1s, $0 |
| Llama 3.1 8B | `openai/llama-3.1-8b` | ~1s, $0 |

### NO USAR
- qwen-* (504 permanente)
- gemini-2.5-pro (cuota agotada)

---

## PERFILES DE WORKER

| Profile | Usa cuando | Modelo |
|---|---|---|
| `executor` | Comando bash, crear archivo, cambio puntual | openai/kimi-k2 |
| `executor-pro` | Editar codigo con contexto amplio | openai/kimi-k2 |
| `researcher` | Leer, investigar, documentar /tmp/ | openai/kimi-k2 |
| `verifier` | PASS/FAIL con output real | openai/gemini-2.5-flash-lite |
| `debugger` | Diagnosticar bug, analizar logs | openai/kimi-k2 |

---

## COSTOS

| Capa | Costo | Hace |
|---|---|---|
| Arquitecto (Opus) | $0.015/1K tokens | SOLO planifica y delega |
| Sonnet capataz | $0.003/1K tokens | SOLO curl dispatch + git |
| Workers Kimi K2 | $0 | TODO: investigar, ejecutar, verificar |
| Verificadores flash-lite | $0 | PASS/FAIL rapido |

Plan tipico: $0.20 - $1.50 total.

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
1. Pre-flight health check -> OK
2. Lock + `boris_start_task` + git tag
3. Plan al Carlos:
   ```
   PLAN: mt5-timeout-220426
   WAVES: 1 (micro)
   COSTO: ~$0.10
   Wave 1: worker edita /home/gestoria/IATRADER-RUST/bridge/mt5_http_server.py
     CAMBIO: 'timeout=30' -> 'timeout=60'
     VERIFICACION: grep 'timeout=60' archivo && echo OK
   ROLLBACK: git reset --hard pre-mt5-timeout-220426
   ¿Apruebas? (si/no/ajustar)
   ```
4. Carlos: "si"
5. `--skip-parl micro`, git tag, 1 Sonnet, 1 worker + 1 verifier
6. Sonnet: dispatch A -> poll -> dispatch B -> poll -> git commit
7. Arquitecto: boris_verify + post-health + push + kb_save + Memory Palace + reporte

---

## EJEMPLO 2 — TAREA CON INVESTIGACION (info insuficiente)

Carlos: "arregla lo que este roto en el servidor"

Arquitecto (no tiene info suficiente):
1. Pre-flight -> OK
2. Lock + boris_start_task
3. Wave 0 planificada: 5 researchers
4. Plan al Carlos:
   ```
   PLAN: server-triage-220426
   WAVES: 2 (investigar + arreglar)
   Wave 0: 5 researchers en paralelo
     - curl health de todos servicios -> /tmp/wave0-health.txt
     - docker ps -> /tmp/wave0-docker.txt
     - systemctl failed -> /tmp/wave0-systemd.txt
     - df+free -> /tmp/wave0-resources.txt
     - journalctl err -> /tmp/wave0-errors.txt
   Wave 1: depende de Wave 0 — plan EXACTO se define tras Wave 0
   ¿Apruebas Wave 0? (Wave 1 la aprobaras despues)
   ```
5. Carlos: "si"
6. Sonnet Wave 0 -> 5 workers researcher -> poll -> reporte con contenido /tmp/wave0-*.txt
7. Arquitecto lee, identifica que esta roto
8. Arquitecto muestra Wave 1 a Carlos con instrucciones exactas
9. Carlos aprueba Wave 1
10. Sonnet Wave 1 -> workers executor -> verifiers -> commit
11. Cierre con reporte enriquecido

---

## EJEMPLO 3 — TAREA MULTI-WAVE CON DEPENDENCIAS

Carlos: "migra la tabla users de schema public a schema auth y actualiza los endpoints"

Arquitecto:
1. Pre-flight + Lock + Boris
2. Plan:
   ```
   PLAN: users-schema-migration-220426
   WAVES: 3
   Wave 1 (BD): migracion SQL — depende de nada
   Wave 2 (API): actualiza 5 endpoints — depende de Wave 1
   Wave 3 (test): corre suite completa — depende de Wave 2
   COSTO: ~$0.80
   ROLLBACK: git reset --hard pre-users-schema + migracion inversa
   ```
3. Carlos aprueba
4. 3 Sonnets secuenciales (cada uno lanza su wave tras checkpoint del anterior)
5. Cierre con reporte de migracion + performance + sugerencias

---

## ERRORES COMUNES

| Error | Fix |
|---|---|
| Arquitecto hace grep/curl para investigar | NO. Wave 0 con researcher workers |
| Arquitecto edita archivos directamente | NO. Worker executor con instruccion exacta |
| Sonnet investiga en vez de despachar | Recordarle: SOLO curl + git |
| Worker "no changes needed" | Prompt vago. Dar linea exacta y cambio exacto |
| Worker pregunta en vez de ejecutar | CLAUDE-executor.md incorrecto en workspace |
| depends_on con strings | Mithos NO acepta strings, solo UUIDs. 2 dispatches separados |
| JSON con comillas en bash | Escribir /tmp/file.json, `curl -d @/tmp/file.json` |
| workers_active no baja a 0 | Poll cada 30-45s, timeout 600s/worker |
| Wave falla 3 veces | PARAR. No improvisar. Escalar a Carlos |
| Lock file huerfano | Verificar PID vivo con `kill -0 $PID` |
| State file corrupto | Leer last valid commit y reconstruir desde git |

---

## ANTI-PATRONES (PROHIBIDO)

- Dispatch sin mostrar plan a Carlos
- Dispatch sin aprobacion explicita ("si/ok/hazlo")
- Saltar pre-flight sin --force
- Workers editando mismo archivo (colision)
- Rehacer wave entera cuando 1 worker falla (usar debugger worker)
- "Ya lo hice" sin kb_save resultado
- Commit sin boris_verify
- git push sin post-health check
- Acumular cambios sin commit por wave
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
- **Skills**: `boris-workflow`, `karpathy-guidelines`, `sypnose-parl-score`
- **MCPs**: `knowledge-hub` (kb_*), `sypnose-memory` (sypnose_*), `boris` (boris_*)
- **Servicios**: Mithos :18810, KB :18791, Memory Palace :18792, LightRAG :18794
- **Herramientas**: git, curl, python3, bash

Si falta cualquiera -> skill aborta en pre-flight con mensaje exacto.

---

## RESUMEN VISUAL DEL FLUJO COMPLETO

```
/sypnose-execute [tarea]
  |
  v
PASO -1: Pre-flight health check (Mithos, KB, Palace, LightRAG, git, disk, ram)
  |
  v
PASO 0: Lock file + boris_start + errores previos + memorias + state file
  |
  v
PASO 1: Planificar waves (instrucciones EXACTAS, anti-colision, file_map, 6 etiquetas)
  |
  v
PASO 2: Mostrar plan + costo a Carlos -> APROBACION EXPLICITA
  |                                              |
  v (si)                                     v (no/ajustar)
PASO 3: PARL Scorecard                     replanificar o abortar
  |
  v
PASO 4: git tag pre-tarea + state persist
  |
  v
PASO 5: Agent(sonnet) por wave
  |                                          |
  v (por cada wave)                          v
  dispatch A (executors) -> poll -> CHECKPOINT
  dispatch B (verifiers) -> poll -> CHECKPOINT
  git commit + tag wave-N-done
  update state + progress files
  |
  v (repeat hasta ultima wave)
  |
  v
PASO 6: boris_verify + post-health + push + 2 memorias (KB+Palace, LightRAG auto)
        + reporte enriquecido (mejoras + inquietudes + sugerencias)
        + auto-cleanup (lock, /tmp/*.json)
  |
  v
REPORTE MARKDOWN FINAL A CARLOS
```

Fin.
