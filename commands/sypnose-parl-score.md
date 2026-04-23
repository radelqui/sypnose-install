---
name: sypnose-parl-score
description: Calcula scorecard PARL sobre un plan antes de dispatch. Detecta serial collapse. Bloquea planes con paralelismo insuficiente.
---

# /sypnose-parl-score

Obligatorio antes de cualquier dispatch. Se invoca sobre un plan completo y devuelve PASS/REDO + métricas.

## INPUT
Plan completo en YAML o JSON, con waves y tasks. Cada task debe declarar tipo (para heurística S_sub).

## FASES

### Fase A — Atomización
Contar total_subtareas N sobre el DAG. Si una tarea compuesta tiene > 1 acción verbal, sub-dividir antes de scorear.

### Fase B — Heurística S_sub pre-exec
Estimación de pasos por sub-tarea (para critical_steps pre-exec):

| Tipo tarea                                    | S_sub |
|-----------------------------------------------|-------|
| Edición simple (str_replace, append, sed)     | 1     |
| Crear archivo nuevo                           | 2     |
| Build / test / lint / type-check              | 3     |
| Migración DB / install deps / apt / pip       | 5     |
| Scraping / multi-request / API pull           | 8     |
| Investigación (sin targets fijos)             | 10    |

Si no encaja → marcar como `S_sub=5` por defecto y flag `heuristic_fallback:true` en output.

### Fase C — Cómputo de métricas
```
N                  = total subtareas
W                  = número de waves
r_parallel_pred    = min(1.0, N / 100)
r_finish_pred      = subtareas_con_verificacion_explicita / N
parallel_ratio     = N / W
concurrency_peak   = max(subtareas_por_wave)
critical_steps     = Σ_w (1 + max(S_sub_i para i en wave w))
total_steps        = Σ_w (suma(S_sub_i para i en wave w))
critical_ratio     = critical_steps / total_steps
```

### Fase D — GATES

| Gate               | Umbral      | Default si falla |
|--------------------|-------------|------------------|
| r_parallel_pred    | ≥ 0.05      | REDO             |
| parallel_ratio     | ≥ 2.0       | REDO             |
| concurrency_peak   | ≥ 2         | REDO             |
| r_finish_pred      | ≥ 0.9       | REDO             |
| critical_ratio     | ≤ 0.6       | REDO*            |

**`*` Excepción critical_ratio**: si el plan documenta cada dependencia secuencial con una razón estructural de la siguiente lista, el gate pasa aunque critical_ratio > 0.6:
- `commit-before-push` (el commit debe existir antes del push)
- `build-before-deploy` (el build debe pasar antes de deploy)
- `create-before-edit` (el archivo debe existir antes de editarlo)
- `schema-before-migrate` (el schema debe actualizarse antes de migrar datos)
- `test-before-tag` (los tests deben pasar antes del tag)
- `pre-flight-before-all` (pre-flight tiene que ir primero por seguridad)

Sin justificación listada → REDO.

### Fase E — REVIEWER AGENT

Se dispara cuando cualquier gate falla (excepto critical_ratio justificado).

- Modelo: `claude-sonnet-4-6` si `critical_steps < 50` Y es 1ª iteración. `claude-opus-4-6` si `critical_steps ≥ 50` O es 2ª iteración.
- Prompt: "Plan con sospecha de serial collapse por gate `<X>` fallido (valor real `<V>`, umbral `<U>`). Atomiza al máximo. Default paralelo; secuencial solo con justificación estructural explícita. Devuelve plan reagrupado en el mismo formato input."
- Max 2 iteraciones. A la 3ª → escalar al SM con plan original + gates fallidos + intentos del reviewer.

## OUTPUT FORMAT (JSON)

```json
{
  "decision": "PASS" | "REDO",
  "metrics": {
    "N": 18, "W": 9,
    "r_parallel_pred": 0.18,
    "r_finish_pred": 0.95,
    "parallel_ratio": 2.0,
    "concurrency_peak": 7,
    "critical_steps": 28,
    "total_steps": 47,
    "critical_ratio": 0.59
  },
  "gates_passed": ["r_parallel","parallel_ratio","concurrency_peak","r_finish","critical_ratio"],
  "gates_failed": [],
  "reviewer_invoked": false,
  "reviewer_iterations": 0,
  "ready_for_dispatch": true,
  "heuristic_fallback": false
}
```

## EXCEPCIONES (REQUIEREN FLAG EXPLÍCITO)

- `--skip-parl micro`: planes triviales de 1 tarea. El flag debe estar declarado en el plan.
- `swarm_dispatch: true`: tareas exploratorias sin targets fijos. El plan se pasa como input único a Kimi K2.6 Agent Swarm (worker de alto nivel). El scorecard se salta. BORIS aplica igual sobre el resultado del Swarm.

## POST-EXEC (calculado por Boris al cerrar)

```
r_parallel_real    = min(1.0, workers_spawned / 100)
r_finish_real      = workers_pass / workers_total
r_perf_real        = verificadores_pass / verificadores_total
critical_steps_real = Σ_w (1 + max(wall_clock_seconds_por_worker_en_wave_w))
```

Todo se escribe en `parl_scorecard.post_exec` del task KB.
