
# SKILL: sypnose-create-plan v2

## Protocolo SM-v3.1 para la Creación de Planes de Ejecución

Este skill define el flujo de trabajo obligatorio para todos los agentes Sypnose de tipo "Arquitecto" o "Planificador". Su objetivo es garantizar que los planes generados sean completos, basados en evidencia y ejecutables de forma fiable.

---

### **FIRMA DE IDENTIDAD (NO MODIFICAR)**

Este skill es parte de la identidad central del sistema Sypnose. Su estructura y principios fundamentales no deben ser alterados sin una revisión explícita por el Arquitecto Jefe (Carlos).

- **Mejora Continua:** Este documento *debe* ser mejorado. Cada `sypnose-v[N]` *debe* incluir una versión actualizada de este skill.
- **Ley del Arquitecto:** El Arquitecto no escribe código; el Arquitecto produce planes. El plan es el artefacto principal. Un plan detallado y verificable es la diferencia entre un `executor` eficiente y un `executor` que alucina.

---

## FLUJO DE TRABAJO OBLIGATORIO (8 PASOS)

### FASE 1: Recopilación de Contexto (Pasos 1-4)

El objetivo es construir un "context blob" exhaustivo para informar la generación del plan. Estos pasos deben ejecutarse en paralelo siempre que sea posible.

**PASO 1: Consultar el Knowledge Graph**
- **Herramienta:** `mcp.graphify.query`
- **Acción:** Realizar una consulta al Knowledge Graph de Sypnose para extraer entidades, relaciones y artefactos relevantes para la tarea. La consulta debe ser lo suficientemente amplia para capturar el contexto del proyecto, pero lo suficientemente específica para evitar el ruido.
- **Ejemplo:** `mcp.graphify.query(query="MATCH (p:Project {name: 'GestoriaRD'})-[:HAS_COMPONENT]->(c) RETURN p, c")`

**PASO 2: Consultar la Memoria a Largo Plazo**
- **Herramienta:** `mcp.sypnose.search`
- **Acción:** Buscar en el "Memory Palace" por experiencias pasadas, lecciones aprendidas, y decisiones de diseño relevantes. Priorizar la búsqueda por `wing` y `room` si se conocen.
- **Ejemplo:** `mcp.sypnose.search(query="quickbooks sync issues", wing="gestoriard", room="tech_debt")`

**PASO 3: Consultar la Base de Conocimiento (KB)**
- **Herramienta:** `mcp.kb.search`
- **Acción:** Realizar una búsqueda en la base de conocimiento documental (markdown, PDFs, etc.). Esto es para encontrar protocolos, guías, y documentación oficial.
- **Ejemplo:** `mcp.kb.search(query="protocolo de deploy en Contabo")`

**PASO 4: Revisar Comunicaciones Recientes**
- **Herramienta:** `mcp.a2a.inbox`
- **Acción:** Revisar la bandeja de entrada del sistema Agent-to-Agent (A2A) en busca de directivas, aclaraciones o actualizaciones de estado de otros agentes que puedan impactar el plan.
- **Ejemplo:** `mcp.a2a.inbox(filter="from:BORIS, status:unread")`

---

### FASE 2: Planificación y Verificación (Pasos 5-7)

**PASO 5: Generar el Plan**
- **Herramienta:** `gemini-pro` (o el modelo de generación asignado)
- **Acción:** Sintetizar todo el contexto recopilado en los pasos 1-4 en un plan de ejecución detallado.
- **Requisitos del Plan:**
    1.  **CITAR FUENTES:** Cada decisión o paso del plan DEBE citar la evidencia de la que se derivó (e.g., `[KB-123]`, `[MEM-5342]`, `[GRAPH-query-result]`).
    2.  **Tareas Atómicas:** Desglosar el trabajo en tareas pequeñas, independientes y verificables.
    3.  **Workers Asignados:** Proponer un tipo de `worker` (e.g., `executor`, `researcher`, `verifier`) para cada tarea.
    4.  **Tests de Aceptación:** Definir cómo se verificará que cada tarea se ha completado correctamente.
    5.  **Gantt Estimado:** Proveer una estimación de tiempo realista para el plan completo.

**PASO 6: Validar el Formato del Plan**
- **Herramienta:** `mcp.boris.verify`
- **Acción:** Enviar el plan generado al agente de validación "BORIS" para asegurar que cumple con todos los requisitos estructurales y de formato del sistema Sypnose. BORIS es el guardián de la consistencia.
- **Ejemplo:** `mcp.boris.verify(document=PLAN_GENERADO, schema="sypnose_plan_v4")`
- **Iteración:** Si BORIS rechaza el plan, volver al PASO 5, corregir los errores y re-enviar.

**PASO 7: Presentar a Revisión Humana**
- **Herramienta:** `AskUserQuestion`
- **Acción:** Presentar el plan validado a Carlos (o al supervisor humano designado) para su aprobación final. La presentación debe ser clara y concisa, resumiendo el objetivo, el coste estimado y los riesgos.
- **Importante:** No proceder sin aprobación explícita.

---

### FASE 3: Ejecución y Cierre (Paso 8)

**PASO 8: Ejecutar y Monitorear**
- **Herramienta:** `claw_dispatch`
- **Acción:** Una vez aprobado, el plan se despacha para su ejecución a través del sistema CLAW. El agente Arquitecto es responsable de monitorear el progreso, manejar escalaciones y registrar los resultados.
- **Registro de Resultados:** Los resultados, artefactos y lecciones aprendidas de la ejecución del plan DEBEN ser grabados de nuevo en las herramientas correspondientes (`graphify`, `sypnose`, `kb`) para cerrar el ciclo de mejora continua.
- **Ejemplo:** `claw_dispatch(plan_file="approved_plan.json")` seguido de `mcp.sypnose.learn(lesson="...")`

---

## CHECKLIST DE CALIDAD DEL PLAN (A ser verificado por BORIS)

- [ ] ¿El plan tiene un objetivo claro y medible?
- [ ] ¿Están todas las tareas desglosadas a su mínima expresión?
- [ ] ¿Cada tarea tiene un `worker` y un `test de aceptación` definidos?
- [ ] ¿Se citan las fuentes de información (KB, Memory Palace, Graph)?
- [ ] ¿Existe una estimación de tiempo y coste (si aplica)?
- [ ] ¿Se han identificado y mitigado los riesgos potenciales?
- [ ] ¿El plan ha pasado la validación de `boris_verify`?
- [ ] ¿El plan sigue la "Ley del Arquitecto" (no prescribe código, sino resultados)?
- [ ] ¿El plan es idempotente donde es posible?
- [ ] ¿El plan considera los posibles estados de fallo y su recuperación?
- [ ] ¿Se ha incluido un paso para la limpieza de recursos?
- [ ] ¿El plan es consistente con los protocolos de seguridad existentes?
- [ ] ¿El plan respeta la regla de "NO TOCAR QUICKBOOKS"?
