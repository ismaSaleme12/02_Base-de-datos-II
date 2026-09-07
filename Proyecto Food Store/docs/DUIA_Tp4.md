# DECLARACIÓN DE USO DE INTELIGENCIA ARTIFICIAL (DUIA) - TRABAJO PRÁCTICO SEMANA 4

## 1. Información General
- **Trabajo Práctico:** Semana 4 — Reportes analíticos asistidos por IA sobre Food Store (Joins, subconsultas, agregación y ventana).
- **Alumno:** Saleme Ismael
- **Asignatura:** Base de Datos II (UTN - TUP a Distancia)
- **Herramientas de IA utilizadas:** OpenCode / Modelos de asistencia de IA.

---

## 2. Registro de Uso por Parte

### Parte 1 — Laboratorio: consultas analíticas lentas y planes de join
- **Herramienta:** OpenCode
- **Prompt / Spec utilizado:**
  > Selección y diseño de consultas analíticas cruzando múltiples tablas (`categoria`, `producto`, `detalle_pedido`, `pedido`, `cliente`) para evaluar algoritmos de join (`Nested Loop`, `Hash Join`, `Merge Join`).
- **Qué se generó:** Propuesta de consultas analíticas complejas y análisis de sus planes de ejecución con `EXPLAIN ANALYZE`.
- **Qué se aceptó y modificó:** Se aceptaron las consultas propuestas tras verificar que aprovechaban eficientemente los índices creados en la Semana 3, obteniendo tiempos de ejecución óptimos (`Nested Loop` y `Merge Join`).

### Parte 2 — Lectura crítica de planes de join interpretados por IA
- **Herramienta:** OpenCode
- **Prompt / Spec utilizado:**
  > Explicación en lenguaje natural de los planes de ejecución con múltiples JOINs.
- **Qué se generó:** Descripciones textuales de los nodos de join y ordenamiento.
- **Qué se aceptó y modificó:** Se realizó el ejercicio crítico de validación cruzada, contrastando la explicación de la IA contra el plan real de PostgreSQL y documentando con precisión los aciertos e imprecisiones detectadas (por ejemplo, diferenciación correcta de tiempos y costos).

### Parte 3 — Consultas resumen, rankings y subconsultas bajo especificación precisa
- **Herramienta:** OpenCode
- **Prompt / Spec utilizado:**
  > Redacción de especificaciones precisas (specs) para (a) un ranking con función de ventana (`DENSE_RANK()`) y (b) una consulta con subconsulta correlacionada, solicitando además alternativas estructurales (CTE) y pruebas de equivalencia con `EXCEPT`.
- **Qué se generó:** El código SQL de las consultas principales, sus alternativas y los bloques de validación formal en `db/consultas_parte3_semana4.sql`.
- **Qué se aceptó y modificó:** Se aceptó el código generado tras verificar que cumplía estrictamente con los filtros de borrado lógico y las especificaciones. Las pruebas con `EXCEPT` fueron ejecutadas exitosamente, arrojando 0 filas en ambas direcciones.

### Parte 4 — Competencia de optimización entre equipos
- **Herramienta:** OpenCode
- **Prompt / Spec utilizado:**
  > Análisis comparativo de rendimiento analítico antes y después sobre consultas con múltiples JOINs y agregación.
- **Qué se generó:** Métricas de rendimiento y justificación técnica basada en la evidencia de los planes de ejecución.
- **Qué se aceptó y modificó:** Se documentaron los resultados de las consultas analíticas en el registro de la competencia.

---

## 3. Conclusión sobre el uso de la IA
Durante la Semana 4, la inteligencia artificial facilitó la construcción de consultas analíticas avanzadas, funciones de ventana y subconsultas correlacionadas complejas. No obstante, aplicando el protocolo de la cátedra, cada consulta fue probada empíricamente en DBeaver, verificada su equivalencia formal mediante operadores relacionales (`EXCEPT`), y analizada críticamente en sus planes de join.
