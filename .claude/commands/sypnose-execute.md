---
name: sypnose-execute
description: Arsenal completo Sypnose v2. El arquitecto planifica waves con instrucciones exactas, hace PARL, lanza Sonnets capataces, workers ejecutan todo. Incluye Boris, KB, git, anti-colisión, verificación entre waves.
user_invocable: true
---

# /sypnose-execute [plan-file.md | "descripcion de la tarea"]

## PRINCIPIOS DE EJECUCIÓN (Karpathy — LEER ANTES DE ACTUAR)

**1. Think Before Coding** — No asumir. Leer lo que existe antes de cambiar. Si hay duda, Wave 0 researcher.
**2. Simplicity First** — Mínimo código que resuelve el problema. Sin features extra, sin abstracciones prematuras.
**3. Surgical Changes** — Tocar solo lo necesario. 1 worker = 1 archivo. No "mejorar" código adyacente.
**4. Goal-Driven** — Definir criterio de éxito ANTES de despachar. No "debería funcionar" — verificar con output real.
**5. Check Errors First** — Antes de planificar cualquier wave, consultar errores previos en el área:
   - Frontend de errores: `[ERROR_FRONTEND_URL]` ← Carlos está construyendo esto
   - Fallback: `kb_search category=lesson project=[tu-proyecto]`
   - Un error ya documentado que se repite = trabajo rechazado automáticamente.

---

## ARQUITECTURA

```
ARQUITECTO (Opus) — planifica waves, escribe instrucciones EXACTAS, lanza Sonnets
  └→ SONNET CAPATAZ (Agent tool) — curl dispatch a Mithos, poll, git commit
       └→ WORKERS KIMI K2 (Mithos :18810) — ejecutan 1 tarea atómica cada uno
            └→ VERIFICADORES (flash-lite) — PASS/FAIL con output real
```

**Regla de oro**: El arquitecto NUNCA ejecuta código. NUNCA lee archivos para implementar.
Los workers hacen TODO: investigar, editar, crear, ejecutar, verificar.

---

## PASO 0 — ANTES DE EMPEZAR (OBLIGATORIO)

```bash
# 1. Boris start (anti-repetición + git pull + tag)
boris_start_task(task_name="[nombre]", task_description="[qué]")
# Si retorna "YA COMPLETADA" → PARAR. No repetir.

# 2. ERRORES PREVIOS — consultar ANTES de planificar cualquier wave
# → Frontend (vivo, visual, filtrable por proyecto/archivo):
#    [ERROR_FRONTEND_URL]  ← Carlos está construyendo esto
# → Fallback hasta que el frontend esté listo:
kb_search category=lesson project=[tu-proyecto]
# Lee los errores. Si hay uno que aplica a tu tarea → lee el FIX antes de continuar.
# Un error que ya ocurrió y se repite = trabajo rechazado automáticamente.

# 3. Memory Palace — busca si alguien ya hizo algo similar
curl -s -X POST http://localhost:18792/sypnose_search \
  -H "Content-Type: application/json" \
  -d '{"params":{"query":"[tema de la tarea]"}}'

# 4. KB — contexto previo del proyecto
kb_search("[tema]")
```

### ERRORES POR ÁREA — Dónde buscar y dónde guardar

Antes de tocar un área, busca errores previos de ESA área. Al fallar, guarda en ESA área.

| Área | Cuándo buscar | Key format |
|---|---|---|
| `frontend` | Antes de tocar React/Next.js/HTML/CSS/UI | `lesson-frontend-[proyecto]-[fecha]` |
| `bd` | Antes de tocar SQL/migrations/Supabase/PostgreSQL | `lesson-bd-[proyecto]-[fecha]` |
| `scripts` | Antes de tocar bash/cron/systemd/automations | `lesson-scripts-[proyecto]-[fecha]` |
| `infra` | Antes de tocar Docker/UFW/nginx/deploy | `lesson-infra-[proyecto]-[fecha]` |
| `api` | Antes de tocar endpoints/RPyC/HTTP/FastAPI | `lesson-api-[proyecto]-[fecha]` |
| `workers` | Antes de despachar a Mithos/dispatch JSON | `lesson-workers-[proyecto]-[fecha]` |

**Buscar errores del área que vas a tocar (PASO 0):**
```bash
# Frontend (error frontend): antes de tocar UI
kb_search "lesson-frontend project=[tu-proyecto] category=lesson"

# BD: antes de tocar base de datos
kb_search "lesson-bd project=[tu-proyecto] category=lesson"

# Scripts: antes de crear/editar scripts bash
kb_search "lesson-scripts project=[tu-proyecto] category=lesson"

# O buscar en el frontend visual: [ERROR_FRONTEND_URL]?area=frontend&project=[tu-proyecto]
```

**Guardar error cuando algo falla (OBLIGATORIO):**
```bash
kb_save key=lesson-[AREA]-[proyecto]-[fecha] category=lesson project=[proyecto]
value="
AREA: frontend | bd | scripts | infra | api | workers
ERROR: [output exacto del fallo — copiar, no parafrasear]
CAUSA: [por qué falló — raíz real, no síntoma]
FIX: [qué comando/cambio lo resolvió]
EVITAR: [qué no hacer la próxima vez en esta área]
ARCHIVOS: [archivos involucrados con rutas completas]
"
```

Ej: worker falla al editar frontend Next.js →
`kb_save key=lesson-frontend-gestoriard-220426 category=lesson project=gestoriard value="AREA: frontend\nERROR: sed reemplazó todas las ocurrencias incluyendo imports\nCAUSA: sed -i 's/x/y/g' sin contexto suficiente\nFIX: usar sed con línea exacta 's/^import x/import y/'\nEVITAR: nunca usar sed global en archivos tsx sin anclar el patrón\nARCHIVOS: /app/components/Modal.tsx"`

---

## PASO 1 — PLANIFICAR WAVES (el trabajo real del arquitecto)

El arquitecto lee lo que Carlos pidió y convierte cada acción en instrucciones EXACTAS para workers.

### Regla de planificación

| Carlos dice | El arquitecto hace |
|---|---|
| "arregla X" | Wave 0 researcher → lee contexto → Wave 1 executor con cambio exacto |
| "implementa Y" | Divide en archivos, 1 worker por archivo, instrucciones line-by-line |
| "investiga Z" | Wave researcher → resultados en /tmp/ → arquitecto lee → Wave executor |
| tarea trivial 1 paso | `--skip-parl micro` + 1 worker directo |

### Formato de instrucción de worker (OBLIGATORIO — 90% del éxito)

```
CONTEXTO: [proyecto], [qué estamos haciendo y por qué]
ARCHIVO: /ruta/exacta/al/archivo.py
ACCIÓN: editar | crear | ejecutar
CAMBIO: linea 45, cambia `return x*2` por `return x*3`
  (o si es crear: contenido completo del archivo)
VERIFICACIÓN: python3 -c "from archivo import func; assert func(2)==6; print('OK')"
SI FALLA: reportar error exacto, NO improvisar cambios adicionales
```

**PROHIBIDO en prompts de workers:**
- "Mejora el código" (subjetivo)
- "Implementa la feature" (vago)
- "Revisa y arregla" (sin target)
- Dar más de 1 tarea por worker

### Anti-colisión (REGLA ABSOLUTA)
1 archivo = 1 worker. NUNCA 2 workers sobre el mismo archivo.
Antes de dispatch, crear mentalmente el file_map:
```
worker-1 → /src/api/auth.ts
worker-2 → /src/api/users.ts
worker-3 → /src/db/schema.sql
```
Si 2 tareas necesitan el mismo archivo → waves diferentes (Wave 1 lo crea, Wave 2 lo edita).

---

## PASO 2 — PARL SCORECARD (OBLIGATORIO antes de dispatch)

Tras dividir el trabajo en waves y escribir las instrucciones exactas:

```
/sypnose-parl-score  [sobre el plan completo]
```

Gates que deben pasar:
- `r_parallel_pred >= 0.05` — hay paralelismo real
- `parallel_ratio >= 2.0` — al menos 2x más tareas paralelas que seriales
- `concurrency_peak >= 2` — pico de 2+ workers simultáneos
- `r_finish_pred >= 0.9` — plan tiene alta probabilidad de terminar
- `critical_ratio <= 0.6` — no más del 60% en cadena serial

Si PASS → kb_save parl_scorecard.pre_exec y proceder.
Si FAIL sin excepción → NO despachar. Reagrupar tareas. Máximo 2 intentos.

Excepciones válidas (documentar en el plan):
- `--skip-parl micro` para tareas de 1 sola acción
- `swarm_dispatch: true` para exploración sin targets fijos

---

## PASO 3 — GIT (ANTES de tocar cualquier archivo)

```bash
git pull origin $(git branch --show-current)
git tag pre-[nombre-tarea] -m "Punto de retorno"
git push origin pre-[nombre-tarea]
```

Si el plan falla tarde → `git reset --hard pre-[nombre-tarea]`

---

## PASO 4 — LANZAR SONNETS CAPATACES

El arquitecto lanza 1 Agent(sonnet) por wave. Si las waves son independientes → paralelo.

```
Agent(
  subagent_type="general-purpose",
  model="sonnet",
  prompt="[TEMPLATE SONNET — ver abajo]"
)
```

**NUNCA opus para Sonnets. SIEMPRE sonnet.**
**El arquitecto NO hace curl. Los Sonnets hacen curl.**

---

## TEMPLATE SONNET CAPATAZ

```
Eres Sonnet capataz de Wave N de M. Tu único trabajo: curl a Mithos + git. NADA MÁS.
NO leas archivos. NO investigues. NO edites nada tú mismo. SOLO despacha y reporta.

WORKSPACE: /ruta/del/proyecto
DESCRIPCIÓN DE ESTA WAVE: [qué hace]

=== DISPATCH A — EXECUTORS ===
Escribe el JSON a /tmp/wave-N-exec.json y ejecuta:

curl -s -X POST http://localhost:18810/dispatch \
  -H "Content-Type: application/json" \
  -d @/tmp/wave-N-exec.json

JSON:
{
  "description": "Wave N — [nombre] executors",
  "workspace": "/ruta/proyecto",
  "keep_workspace": true,
  "max_parallel": 30,
  "tasks": [
    {
      "profile": "executor",
      "description": "[INSTRUCCION EXACTA con CONTEXTO+ARCHIVO+ACCIÓN+CAMBIO+VERIFICACIÓN+SI FALLA]",
      "timeout_secs": 600,
      "model": "openai/kimi-k2"
    }
  ]
}

=== POLL A ===
Ejecuta cada 30s hasta workers_active=0:
curl -s http://localhost:18810/health

=== DISPATCH B — VERIFIERS ===
Escribe el JSON a /tmp/wave-N-verify.json y ejecuta:

curl -s -X POST http://localhost:18810/dispatch \
  -H "Content-Type: application/json" \
  -d @/tmp/wave-N-verify.json

JSON:
{
  "description": "Wave N — [nombre] verifiers",
  "workspace": "/ruta/proyecto",
  "keep_workspace": true,
  "max_parallel": 30,
  "tasks": [
    {
      "profile": "verifier",
      "description": "Verifica que Wave N completó: [ls archivos], [cat archivo | grep cambio esperado], [build command]. Reporta PASS o FAIL con output exacto copiado.",
      "timeout_secs": 120,
      "model": "openai/gemini-2.5-flash-lite"
    }
  ]
}

=== POLL B ===
curl -s http://localhost:18810/health hasta workers_active=0.

=== GIT (solo si verificadores dicen PASS) ===
cd /ruta/proyecto
mkdir -p .brain
cat > .brain/wave-N-status.md << 'EOF'
wave: N
timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)
workers: X exitosos, Y fallidos
archivos: [lista]
verificacion: PASS
EOF
git add [archivos específicos modificados — NUNCA git add .]
git commit -m "[WAVE-N] [descripción del cambio]"

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

## MODELOS DISPONIBLES

### Workers (ejecutan código)
| Modelo | ID dispatch | Notas |
|---|---|---|
| Kimi K2 (primario) | `openai/kimi-k2` | $0, 30+ paralelo |
| Kimi K2-0905 | `openai/kimi-k2-0905` | $0, backup |
| Kimi K2.6 | `openai/kimi-k2.6` | $0, fallback |
| DeepSeek V3 | `openai/deepseek-v3` | $0, fallback final |

Fallback automático: kimi-k2 → kimi-k2-0905 → kimi-k2.6 → deepseek-v3

### Verificadores (comprueban output)
| Modelo | ID dispatch | Velocidad |
|---|---|---|
| Gemini Flash Lite (primario) | `openai/gemini-2.5-flash-lite` | ~2s, $0 |
| Cerebras Llama 8B | `openai/cerebras-llama-8b` | ~1s, $0 |
| Llama 3.1 8B | `openai/llama-3.1-8b` | ~1s, $0 |

### NO USAR
- qwen-* (504 permanente)
- gemini-2.5-pro (cuota agotada frecuente)

### Prefijo openai/ OBLIGATORIO en todos los model IDs

---

## PERFILES DE WORKER

| Profile | Usa cuando | Modelo recomendado |
|---|---|---|
| `executor` | Comando bash, crear archivo, cambio puntual | openai/kimi-k2 |
| `executor-pro` | Editar código que requiere leer contexto amplio | openai/kimi-k2 |
| `researcher` | Leer código, investigar, documentar hallazgos en /tmp/ | openai/kimi-k2 |
| `verifier` | Verificar que algo funciona, PASS/FAIL con output real | openai/gemini-2.5-flash-lite |
| `debugger` | Diagnosticar bug, analizar logs/errores | openai/kimi-k2 |

---

## FLUJO CON INVESTIGACIÓN PREVIA (Wave 0)

Cuando el arquitecto no tiene suficiente información para escribir instrucciones exactas:

```
Wave 0 (researchers):
  → Workers leen archivos, investigan, escriben resultados en /tmp/wave0-*.txt
  → Sonnet reporta resultados al Arquitecto

Arquitecto lee /tmp/wave0-*.txt y YA puede escribir instrucciones exactas.

Wave 1 (executors + verifiers): instrucciones exactas basadas en Wave 0
Wave 2 (si aplica): depende de Wave 1
```

---

## CHECKPOINT ENTRE WAVES (OBLIGATORIO)

**NO pasar a Wave N+1 sin verificar Wave N:**

```
[ ] Verificadores: PASS en todos los workers
[ ] Build/lint check: [comando] → sin errores
[ ] git diff: solo archivos esperados modificados
[ ] git commit -m "[WAVE-N] descripción"
```

Si un worker falla → Sonnet despacha 1 debugger worker (NO rehace la wave entera).
Si 3 waves fallan → PARAR. Reportar al arquitecto con error exacto. Escalar a Carlos.

---

## PASO 5 — AL TERMINAR TODAS LAS WAVES

```bash
# 1. git push
git push origin $(git branch --show-current)

# 2. boris_verify (OBLIGATORIO antes de declarar completado)
boris_verify(
  what_changed="[qué cambió]",
  how_verified="[comando exacto ejecutado]",
  result="[output real copiado — mín 15 chars]"
)

# 3. git add .brain/ && git commit -m "[BRAIN] wave-summary [fecha]" && git push

# 4. boris_register_done
boris_register_done(task_name="[nombre]", verification_summary="[resumen]")

# 5. KB save final (OBLIGATORIO — el SM no sabe que terminaste sin esto)
kb_save key=resultado-[arquitecto]-[nombre]-[fecha] category=notification project=[proyecto]
value="
DONE: [qué ejecutaste]
COMMITS: [hashes]
VERIFICADO: [qué comprobaste con output real]
WAVES: [N completadas de M total]
WORKERS: [total lanzados, exitosos, fallidos]
DESCUBRIMIENTOS: [bugs, mejoras, riesgos encontrados]
SUGERENCIAS: [próximo paso recomendado]
"

# 6. Memory Palace
curl -s -X POST http://localhost:18792/sypnose_add \
  -H "Content-Type: application/json" \
  -d '{"params":{"wing":"[proyecto]","room":"[tema]","content":"[qué hiciste y resultado]","summary":"[resumen corto]"}}'
```

---

---

## PROTOCOLO DE ERRORES — GUARDAR Y REPORTAR

### Reportar error (PASS / FAIL — solo estos dos valores, nada más)

**Verifier** → solo puede decir:
```
PASS: [output exacto que lo confirma]
FAIL: [output exacto del error]
```

**Sonnet capataz** → reporta al Arquitecto:
```
WAVE: N de M
STATUS: done | failed         ← solo estos dos
WORKERS: X exitosos, Y fallidos
FALLO: [qué worker falló, con output exacto]
```

**Arquitecto** → reporta a Carlos:
```
AREA: [frontend|bd|scripts|infra|api|workers]
STATUS: PASS | FAIL
ERROR: [output real — nunca parafrasear]
```

Si el error es urgente (servicio caído, BD corrupta, deploy roto):
```bash
# Notificar canal de alertas inmediatamente
channel_publish channel=system-alerts message="ERROR [AREA] [proyecto]: [descripción en 1 línea]"
```

---

### Guardar error (OBLIGATORIO cuando STATUS: failed)

```bash
kb_save \
  key=lesson-[AREA]-[proyecto]-$(date +%Y%m%d) \
  category=lesson \
  project=[proyecto] \
  value="
AREA: [frontend|bd|scripts|infra|api|workers]
ERROR: [output exacto — copiar sin parafrasear]
CAUSA: [raíz real del problema, no el síntoma]
FIX: [comando o cambio exacto que lo resolvió]
EVITAR: [regla concreta para no repetirlo]
ARCHIVOS: [rutas completas de archivos involucrados]
"
```

**Áreas y cuándo guardar:**
| Área | Guardar cuando falla... |
|---|---|
| `frontend` | worker edita .tsx/.jsx/.html/.css y el build rompe o la UI no muestra |
| `bd` | migración falla, SELECT da datos incorrectos, schema no existe |
| `scripts` | bash -n falla, cron no corre, systemd unit error |
| `infra` | docker build falla, container no arranca, UFW bloquea tráfico esperado |
| `api` | endpoint retorna 4xx/5xx, RPyC no conecta, timeout |
| `workers` | worker dice "no changes needed", dispatch JSON inválido, timeout |

**Buscar antes de tocar (PASO 0 — según área que vas a modificar):**
```bash
kb_search "lesson-frontend"   # si vas a tocar UI
kb_search "lesson-bd"         # si vas a tocar BD
kb_search "lesson-scripts"    # si vas a tocar scripts
kb_search "lesson-infra"      # si vas a tocar Docker/deploy
kb_search "lesson-api"        # si vas a tocar endpoints
kb_search "lesson-workers"    # si vas a despachar workers
# O visual: [ERROR_FRONTEND_URL]?area=[area]&project=[proyecto]
```

---

## ERRORES COMUNES

| Error | Fix |
|---|---|
| Arquitecto hace grep/curl para investigar | NO. Lanza Wave 0 con workers researcher |
| Arquitecto edita archivos directamente | NO. Worker executor con instrucción exacta |
| Sonnet investiga en vez de despachar | Recordarle: SOLO curl a Mithos y git |
| Worker dice "no changes needed" | Prompt vago. Dar línea exacta y cambio exacto |
| Worker pregunta en vez de ejecutar | Prompt vago o CLAUDE.md incorrecto en workspace |
| depends_on con strings en JSON | Mithos NO acepta strings, solo UUIDs. Hacer 2 dispatches separados |
| JSON con comillas especiales en bash | Escribir JSON a /tmp/archivo.json, luego `curl -d @/tmp/archivo.json` |
| workers_active no baja a 0 | Poll cada 30s, timeout 600s por worker |
| Wave falla 3 veces | PARAR. No improvisar. Escalar a Carlos con error exacto |

---

## COSTOS

| Capa | Costo | Hace |
|---|---|---|
| Arquitecto (Opus) | $0.15/1K tokens | SOLO planifica y delega |
| Sonnet capataz | $0.03/1K tokens | SOLO curl dispatch + git |
| Workers Kimi K2 | $0 | TODO: investigar, ejecutar, verificar |
| Verificadores flash-lite | $0 | PASS/FAIL rápido |

---

## EJEMPLO — TAREA SIMPLE (info suficiente)

Carlos: "cambia el timeout de mt5_http_server.py de 30 a 60 segundos"

Arquitecto:
1. `boris_start_task` + git tag
2. `--skip-parl micro` (1 sola tarea)
3. Lanza 1 Sonnet:
   ```
   Despacha 1 executor: CONTEXTO: IATRADER-RUST bridge. ARCHIVO: /home/gestoria/IATRADER-RUST/bridge/mt5_http_server.py. ACCIÓN: editar. CAMBIO: busca 'timeout=30' y reemplaza por 'timeout=60'. VERIFICACIÓN: grep 'timeout=60' /home/gestoria/IATRADER-RUST/bridge/mt5_http_server.py && echo OK. SI FALLA: reportar línea exacta donde está timeout.
   Luego 1 verifier: grep -n timeout /home/gestoria/IATRADER-RUST/bridge/mt5_http_server.py. Git commit + push.
   ```
4. Sonnet hace 2 curls + 1 git commit. Reporta.
5. Arquitecto: boris_verify + kb_save.

---

## EJEMPLO — TAREA CON INVESTIGACIÓN (info insuficiente)

Carlos: "arregla lo que esté roto en el servidor"

Arquitecto (no tiene info suficiente):
1. `boris_start_task` + git tag
2. Lanza Sonnet Wave 0 (researchers):
   ```
   Despacha 5 workers researcher:
   1. curl -s http://localhost:18810/health && curl -s http://localhost:18820/health — escribe en /tmp/wave0-health.txt
   2. docker ps --format 'table {{.Names}}\t{{.Status}}' — escribe en /tmp/wave0-docker.txt
   3. systemctl list-units --state=failed — escribe en /tmp/wave0-systemd.txt
   4. df -h && free -h — escribe en /tmp/wave0-resources.txt
   5. journalctl -n 50 --no-pager -p err — escribe en /tmp/wave0-errors.txt
   ```
3. Sonnet despacha, poll, reporta con contenido de /tmp/wave0-*.txt
4. Arquitecto lee resultados, identifica qué está roto
5. Lanza Sonnet Wave 1 con instrucciones exactas para arreglar
