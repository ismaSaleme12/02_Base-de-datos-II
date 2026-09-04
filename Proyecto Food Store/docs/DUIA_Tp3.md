# DECLARACIÓN DE USO DE INTELIGENCIA ARTIFICIAL (DUIA) - TRABAJO PRÁCTICO SEMANA 3

## 1. Información General
- **Trabajo Práctico:** Semana 3 — Optimización asistida por IA sobre Food Store (Filtros, planes de ejecución e índices).
- **Alumno:** Saleme Ismael
- **Asignatura:** Base de Datos II (UTN - TUP a Distancia)
- **Herramientas de IA utilizadas:** OpenCode / Modelos de asistencia de IA.

---

## 2. Registro de Uso por Parte

### Parte 1 — Carga masiva de datos
- **Herramienta:** OpenCode
- **Prompt / Spec utilizado:**
  > "Generá un script SQL para PostgreSQL que inserte 50.000 filas en producto, distribuidas de forma pareja entre las categorías existentes, con precios entre 500 y 5000 y stock aleatorio entre 0 y 200, 20.000 usuarios y 200.000 pedidos con sus detalles. Usá generate_series y no uses PL/pgSQL si no es necesario. No modifiques ninguna otra tabla. Respeta las restricciones (CHECK, UNIQUE, FK) y que no toque la base de producción."
- **Qué se generó:** Un script SQL completo (`db/carga_masiva.sql`) con truncaado de tablas, reinicio de identidades (`RESTART IDENTITY CASCADE`), inserción masiva mediante `generate_series` y transaccionalidad.
- **Qué se aceptó y modificó:** Se aceptó la lógica de generación con `generate_series` y el uso de transacciones con resguardo. Se ajustó manualmente la asignación de claves foráneas y la desactivación temporal de triggers diferidos para garantizar una carga masiva limpia sin violar la regla de negocio de pedidos.

### Parte 2 — Laboratorio de consultas lentas y EXPLAIN ANALYZE
- **Herramienta:** OpenCode
- **Prompt / Spec utilizado:**
  > Análisis de planes de ejecución (`EXPLAIN ANALYZE`) para tres consultas complejas sobre la base masiva, solicitando propuestas de índices y reescrituras justificadas por nodo de costo.
- **Qué se generó:** Propuesta de índices compuestos y unicolumna (`idx_producto_cat_precio`, `idx_pedido_cliente_id`, `idx_detalle_pedido_producto_id`).
- **Qué se aceptó y modificó:** Se aceptó la creación de los índices y se midió empíricamente el rendimiento antes y después. Se documentó objetivamente el comportamiento real: la Consulta 1 mostró mejora leve, la Consulta 2 se mantuvo estable, y la Consulta 3 evidenció que el optimizador prefirió un `Sequential Scan` masivo sobre el uso de índices debido a la alta cardinalidad de filas accedidas.

### Parte 3 — Lectura crítica de planes interpretados por IA
- **Herramienta:** OpenCode
- **Prompt / Spec utilizado:**
  > Análisis y explicación en lenguaje natural del plan de ejecución de la Consulta 1 con índice aplicado.
- **Qué se generó:** Explicación textual nodo por nodo del plan.
- **Qué se aceptó y modificó:** Ejercicio crítico de validación donde se detectaron y corrigieron imprecisiones de la IA (como la confusión entre costo estimado y milisegundos reales, o la suposición de que no se usó memoria de ordenamiento cuando el plan indicaba uso de `quicksort`).

### Parte 4 — Consultas resumen y subconsultas bajo especificación precisa
- **Herramienta:** OpenCode
- **Prompt / Spec utilizado:**
  > Especificación precisa (spec) para una consulta de agregación y una consulta con subconsulta sobre Food Store, pidiendo generación de SQL y alternativas estructurales (CTE / JOIN).
- **Qué se generó:** Las consultas principales, sus alternativas y los bloques de verificación formal con `EXCEPT`.
- **Qué se aceptó y modificó:** Se aceptó la estructura propuesta y se ejecutaron las pruebas de equivalencia (`EXCEPT`), las cuales devolvieron 0 filas en ambas direcciones, confirmando la equivalencia formal de los resultados.

### Parte 5 — Competencia de optimización entre equipos
- **Herramienta:** OpenCode
- **Prompt / Spec utilizado:**
  > Evaluación comparativa de tiempos de ejecución real (`EXPLAIN ANALYZE`) antes y después de aplicar estrategias de optimización.
- **Qué se generó:** Registro comparativo de rendimiento (tiempos y métricas de mejora).
- **Qué se aceptó y modificó:** Se documentó formalmente el resultado de la Consulta 2 (tiempo estable de ~0.12ms a ~0.26ms) aplicando criterio técnico sustentado en la evidencia empírica del motor de base de datos.

---

## 3. Conclusión sobre el uso de la IA
La inteligencia artificial actuó como motor primario de asistencia para la redacción de scripts, propuestas de indexación y redacción de especificaciones. Sin embargo, en cumplimiento estricto del protocolo de la cátedra, **ninguna propuesta fue aceptada a ciegas**: cada plan de ejecución fue medido empíricamente con `EXPLAIN ANALYZE`, cada resultado fue contrastado críticamente frente al motor real de PostgreSQL, y las decisiones se justificaron en función de la evidencia empírica obtenida.
