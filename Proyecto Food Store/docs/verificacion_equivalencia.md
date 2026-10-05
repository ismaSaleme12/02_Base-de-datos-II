# Verificación de equivalencia — Parte D
**Food Store · `usuario` vs `usuario_anon` · 2026-10-05**

## 1. Consultas de agregación (usuarios por rol y mes de alta)

Sobre anonimizada (pedida a la IA con precisión):

```sql
-- Q_ANON: cantidad por rol y mes sobre usuario_anon
SELECT rol, mes_alta, COUNT(*) AS total
FROM usuario_anon
GROUP BY rol, mes_alta
ORDER BY mes_alta, rol;
```

Equivalente sobre tabla real (devuelta por la IA):

```sql
-- Q_REAL: misma agregación sobre usuario
SELECT rol, to_char(fecha_alta, 'YYYY-MM') AS mes_alta, COUNT(*) AS total
FROM usuario
GROUP BY rol, to_char(fecha_alta, 'YYYY-MM')
ORDER BY mes_alta, rol;
```

Chequeo de igualdad fila a fila:

```sql
(SELECT rol, to_char(fecha_alta,'YYYY-MM') AS mes, COUNT(*) FROM usuario
 GROUP BY 1,2 EXCEPT
 SELECT rol, mes_alta, COUNT(*) FROM usuario_anon GROUP BY 1,2)
UNION ALL
(SELECT rol, mes_alta, COUNT(*) FROM usuario_anon GROUP BY 1,2 EXCEPT
 SELECT rol, to_char(fecha_alta,'YYYY-MM'), COUNT(*) FROM usuario GROUP BY 1,2);
-- Esperado: 0 filas (equivalentes).
```

## 2. Evidencia real (ejecución 2026-10-05, 9 usuarios: 8 semilla + 1 simulacro)

Q_ANON y Q_REAL devuelven idéntico resultado:

| rol | mes_alta | total_anon | total_real | coincide |
|-----|----------|------------|------------|----------|
| cliente | 2026-01 | 2 | 2 | ✅ |
| soporte | 2026-01 | 1 | 1 | ✅ |
| admin | 2026-02 | 1 | 1 | ✅ |
| soporte | 2026-02 | 1 | 1 | ✅ |
| cliente | 2026-03 | 2 | 2 | ✅ |
| reportes | 2026-03 | 1 | 1 | ✅ |
| cliente | 2026-10 | 1 | 1 | ✅ |

Chequeo `EXCEPT` cruzado: **0 filas** (equivalentes). Conteos:
`(SELECT COUNT(*) FROM usuario)` = 9, `(SELECT COUNT(*) FROM usuario_anon)` = 9.
(Nota: `SELECT COUNT(*) AS x, (SELECT ...)` sin FROM devuelve 1 para la primera
columna; el conteo correcto usa subselects en ambas columnas.)

## 3. Qué no debe salir nunca hacia la IA sin anonimización

Nunca deben enviarse a un asistente de IA sin pasar por `usuario_anon` el `email`
real, el `nombre` real, el `password_hash`, ni combinaciones reidentificables
(`rol` + `fecha_alta` exacta + `id`). Sólo viajan agregados o seudónimos
deterministas (`usuario.NNNNN@sintetico.test`, `USUARIO_SINT_NNNNN`, `YYYY-MM`),
porque un log o un prompt con PII se convierte en una copia no controlada del dato.
