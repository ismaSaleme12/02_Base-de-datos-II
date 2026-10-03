-- =====================================================================
-- TP Unidad 4 — Parte 2: Desnormalización controlada (Food Store)
-- Archivo: tp_desnormalizacion_top_categorias.sql
-- Base objetivo: Food_Store_Copia (NO ejecutar sobre Food_Store)
-- Contenido: estructura desnormalizada + sincronización + consulta
--            optimizada (5.2.d) + auditoría de sincronía (5.2.e)
-- ---------------------------------------------------------------------
-- ADAPTACIONES DOCUMENTADAS respecto del enunciado 5.1:
--  1. detalle_pedido no tiene columna "subtotal": se usa
--     (cantidad * precio_unitario), que es su definición de negocio.
--  2. pedido y detalle_pedido no tienen columna "eliminado": los
--     filtros dp.eliminado/ped.eliminado se omiten (no hay borrado
--     lógico en este esquema).
--  3. No hay pedidos con fecha de hoy (rango 2025-09-04 a 2026-09-04):
--     el "día" del reporte es el día con datos más reciente,
--     (SELECT MAX(fecha::date) FROM pedido), equivalente funcional
--     de CURRENT_DATE sobre esta instancia.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 5.2(a). CONSULTA BASE (normalizada) — referencia para EXPLAIN ANALYZE.
-- Tiempo medido: ~74 ms. Nodo dominante: Parallel Seq Scan sobre
-- pedido (filtro fecha::date elimina 199.596 de 200.000 filas) +
-- Parallel Seq Scan sobre detalle_pedido + Hash Join.
-- ---------------------------------------------------------------------
-- EXPLAIN (ANALYZE, TIMING ON)
-- SELECT c.nombre AS categoria,
--        SUM(dp.cantidad * dp.precio_unitario) AS total_vendido
-- FROM detalle_pedido dp
-- JOIN producto pr ON pr.id = dp.producto_id
-- JOIN categoria c ON c.id = pr.categoria_id
-- JOIN pedido ped ON ped.id = dp.pedido_id
-- WHERE ped.fecha::date = (SELECT MAX(fecha::date) FROM pedido)
-- GROUP BY c.nombre
-- ORDER BY total_vendido DESC
-- LIMIT 5;

-- ---------------------------------------------------------------------
-- 5.2(b). PATRÓN ELEGIDO: tabla de agregados diarios con disparador.
-- (Justificación de un párrafo para el informe: la medición de (a)
-- muestra que el costo lo dominan los recorridos completos de pedido
-- y detalle_pedido por el filtro no indexable fecha::date más los 3
-- JOINs y el GROUP BY, para un resultado final de solo 10 grupos;
-- una vista materializada quedaría obsoleta entre REFRESH y REFRESH
-- justo en un panel "en tiempo real", mientras que la tabla de
-- agregados se mantiene sincronizada por disparadores AFTER
-- INSERT/UPDATE/DELETE sobre detalle_pedido y es totalmente
-- reversible sin pérdida: basta DROP TABLE + DROP TRIGGER porque la
-- fuente de verdad sigue intacta.)
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- 5.2(c). ESTRUCTURA DESNORMALIZADA + MECANISMO DE SINCRONIZACIÓN.
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS resumen_venta_categoria_dia CASCADE;

CREATE TABLE resumen_venta_categoria_dia (
    dia          DATE          NOT NULL,
    categoria_id BIGINT        NOT NULL REFERENCES categoria(id),
    total_vendido NUMERIC(14,2) NOT NULL DEFAULT 0 CHECK (total_vendido >= 0),
    PRIMARY KEY (dia, categoria_id)
);

-- Carga inicial (backfill) desde la fuente de verdad.
INSERT INTO resumen_venta_categoria_dia (dia, categoria_id, total_vendido)
SELECT ped.fecha::date AS dia,
       pr.categoria_id,
       SUM(dp.cantidad * dp.precio_unitario) AS total_vendido
FROM detalle_pedido dp
JOIN producto pr ON pr.id = dp.producto_id
JOIN pedido ped ON ped.id = dp.pedido_id
GROUP BY ped.fecha::date, pr.categoria_id
ON CONFLICT (dia, categoria_id) DO UPDATE
SET total_vendido = EXCLUDED.total_vendido;

-- Función de sincronización: aplica el delta de cada fila de detalle.
CREATE OR REPLACE FUNCTION fn_sync_resumen_venta_categoria()
RETURNS TRIGGER AS $$
DECLARE
    v_dia DATE;
    v_cat BIGINT;
BEGIN
    IF TG_OP = 'DELETE' THEN
        SELECT ped.fecha::date, pr.categoria_id
          INTO v_dia, v_cat
        FROM pedido ped, producto pr
        WHERE ped.id = OLD.pedido_id AND pr.id = OLD.producto_id;
        UPDATE resumen_venta_categoria_dia
           SET total_vendido = total_vendido - (OLD.cantidad * OLD.precio_unitario)
         WHERE dia = v_dia AND categoria_id = v_cat;
        RETURN OLD;
    ELSE
        -- INSERT o UPDATE: reversa el aporte anterior (si había) y suma el nuevo.
        IF TG_OP = 'UPDATE' THEN
            SELECT ped.fecha::date, pr.categoria_id
              INTO v_dia, v_cat
            FROM pedido ped, producto pr
            WHERE ped.id = OLD.pedido_id AND pr.id = OLD.producto_id;
            UPDATE resumen_venta_categoria_dia
               SET total_vendido = total_vendido - (OLD.cantidad * OLD.precio_unitario)
             WHERE dia = v_dia AND categoria_id = v_cat;
        END IF;
        SELECT ped.fecha::date, pr.categoria_id
          INTO v_dia, v_cat
        FROM pedido ped, producto pr
        WHERE ped.id = NEW.pedido_id AND pr.id = NEW.producto_id;
        INSERT INTO resumen_venta_categoria_dia (dia, categoria_id, total_vendido)
        VALUES (v_dia, v_cat, NEW.cantidad * NEW.precio_unitario)
        ON CONFLICT (dia, categoria_id) DO UPDATE
        SET total_vendido = resumen_venta_categoria_dia.total_vendido
                          + (NEW.cantidad * NEW.precio_unitario);
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_resumen_venta ON detalle_pedido;

CREATE TRIGGER trg_sync_resumen_venta
AFTER INSERT OR UPDATE OR DELETE ON detalle_pedido
FOR EACH ROW EXECUTE FUNCTION fn_sync_resumen_venta_categoria();

-- ---------------------------------------------------------------------
-- 5.2(d). CONSULTA sobre la estructura desnormalizada (mismo reporte).
-- ---------------------------------------------------------------------
-- EXPLAIN (ANALYZE, TIMING ON)
SELECT c.nombre AS categoria,
       r.total_vendido
FROM resumen_venta_categoria_dia r
JOIN categoria c ON c.id = r.categoria_id
WHERE r.dia = (SELECT MAX(dia) FROM resumen_venta_categoria_dia)
ORDER BY r.total_vendido DESC
LIMIT 5;

-- ---------------------------------------------------------------------
-- 5.2(e). AUDITORÍA: filas donde el resumen difiere de la fuente de
-- verdad. Debe devolver 0 filas sobre la base migrada.
-- ---------------------------------------------------------------------
SELECT r.dia,
       r.categoria_id,
       r.total_vendido AS resumen,
       COALESCE(t.real, 0) AS fuente_verdad
FROM resumen_venta_categoria_dia r
FULL JOIN (
    SELECT ped.fecha::date AS dia,
           pr.categoria_id,
           SUM(dp.cantidad * dp.precio_unitario) AS real
    FROM detalle_pedido dp
    JOIN producto pr ON pr.id = dp.producto_id
    JOIN pedido ped ON ped.id = dp.pedido_id
    GROUP BY ped.fecha::date, pr.categoria_id
) t USING (dia, categoria_id)
WHERE r.total_vendido IS DISTINCT FROM COALESCE(t.real, 0);
