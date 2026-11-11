# requirements.md — Food Store: sincronización de la tablet en la feria

**Proyecto:** Food Store · Base de Datos II · TP 8 (Unidad 8)
**Change:** `tp8-sincronizacion-tablet`
**Notación:** EARS (Easy Approach to Requirements Syntax)

## Contexto

El food truck vende en una feria **sin señal**. La tablet guarda una copia del
catálogo en SQLite y arma borradores de pedido. Cuando recupera conexión, envía
cada borrador como una *solicitud* y el servidor decide si la aceptaría.

**Regla de oro:** el móvil propone, el servidor dispone. Precio, stock y ventas
los decide PostgreSQL. La tablet **nunca** escribe sobre PostgreSQL.

---

## REQ-01 — Conflicto de precio

> **WHEN** el precio actual del servidor difiere del precio que el cliente vio en
> el borrador
> **THE SYSTEM SHALL** marcar la solicitud como `CONFLICTO` e informar el precio
> visto y el precio actual en el campo `motivo`.

**Se prueba con:** caso **C2** (el servidor sube el precio de 111923 a 126923
centavos y la solicitud pasa de `PENDIENTE` a `CONFLICTO`).

**Precedencia:** si además hay un problema de existencia, baja o stock, gana el
rojo. El amarillo es el caso "no hay nada roto, sólo cambió el precio".

---

## REQ-02 — Stock insuficiente

> **IF** la cantidad pedida en un ítem supera el `stock_visto` de la instantánea
> **THEN THE SYSTEM SHALL** marcar la solicitud como `RECHAZADO` e indicar en el
> `motivo` la cantidad pedida y la disponible.

**Se prueba con:** caso **C3** (producto 95 con stock 3, se piden 10 unidades →
`RECHAZADO: producto 95: no alcanza el stock (pide 10, hay 3)`).

---

## REQ-03 — Producto dado de baja

> **WHILE** un producto figure en la instantánea con `eliminado = 1`
> **THE SYSTEM SHALL** excluirlo del catálogo visible para el vendedor y
> rechazar cualquier borrador que lo incluya, **conservando la fila** en
> `producto_cache`.

**Se prueba con:** caso **C4** (el producto 6 se da de baja lógica en el
servidor: la solicitud da `RECHAZADO: producto 6: dado de baja`, el producto
sale del catálogo y la fila queda con `eliminado = 1`).

**Por qué la fila no se borra:** si se borrara, el borrador histórico perdería
su clave foránea y no se podría distinguir "dado de baja" de "no existe".

---

## REQ-04 — Idempotencia del reenvío

> **WHEN** se reenvía una solicitud cuyo `solicitud_uuid` ya existe
> **THE SYSTEM SHALL** rechazar el envío por violación de clave primaria, sin
> duplicar la solicitud y sin reevaluar las ya resueltas.

**Se prueba con:** caso **C6** (reenviar el UUID
`50000000-0000-4000-8000-000000000005` devuelve
`UNIQUE constraint failed: cola_sync.solicitud_uuid`; correr el semáforo otra
vez deja los cinco estados idénticos).

**Alcance explícito:** esta protección es del lado del cliente. La protección
real de un sistema en producción vive en el servidor, dentro de la transacción
que crea el pedido. Ver `design.md §6`.

---

## Fuera de alcance

- Confirmar la venta y descontar stock: el semáforo **no** escribe en
  PostgreSQL. `SIMULADO_APROBADO` no es una venta.
- Interfaz de usuario, app de celular.
- Resolución automática de conflictos: alguien decide, el sistema sólo informa.
