# 🛒 Proyecto Food Store — Base de Datos II

<p align="center">
  <b>Sistema Integral de Gestión de Base de Datos relacional para comercio gastronómico</b><br>
  <i>Materia: Base de Datos II • Ismael Saleme, Sabrina Gimenez, Jeronimo Coronel y Joaquin Godoy</i>
</p>

---

## 📌 Tabla de Contenidos

1. [Descripción General](#-descripción-general)
2. [Arquitectura y Estructura del Repositorio](#-arquitectura-y-estructura-del-repositorio)
3. [Módulos Principales del Proyecto](#-módulos-principales-del-proyecto)
4. [Base de Datos y Seguridad](#-base-de-datos-y-seguridad)
5. [Documentación Complementaria](#-documentación-complementaria)
6. [Guía de Respaldo y Restauración](#-guía-de-respaldo-y-restauración)

---

## 🎯 Descripción General

**Food Store** es un proyecto práctico desarrollado en el marco de la materia **Base de Datos II**. Su propósito es diseñar, implementar, optimizar y administrar una base de datos relacional robusta en **PostgreSQL**, abarcando desde el modelado conceptual y la definición de esquemas hasta el control avanzado de transacciones, concurrencia, reglas de integridad y consultas complejas.

---

## 📂 Arquitectura y Estructura del Repositorio

El proyecto se organiza de manera modular para separar los scripts de base de datos, la documentación teórica/práctica y las configuraciones de entorno:

```text
Proyecto Food Store/
├── db/
│   ├── backups/                  # Respaldos de seguridad (pg_dump)
│   ├── schema_tp1.sql            # Esquema relacional inicial
│   ├── reglas_integridad.sql     # Triggers y validaciones de negocio
│   ├── carga_masiva_datos - Tp3.sql # Scripts de población masiva
│   ├── consultas_*.sql           # Consultas de análisis, optimización y reportes
│   └── Sesion A/B (*).sql        # Scripts para laboratorio de concurrencia
├── docs/
│   ├── README.md                 # Documentación general del proyecto (este archivo)
│   ├── spec_integridad.md        # Especificación formal de reglas de integridad
│   ├── informe_concurrencia.md   # Laboratorio de transacciones y aislamiento
│   ├── ejercicio_lectura_critica.md # Análisis crítico de rendimiento
│   └── DUIA_*.md                 # Documentación unificada de actividades (TPs)
├── .kiro/                        # Configuraciones de asistencia y steering
├── AGENTS.md                     # Protocolos de seguridad e instrucciones de agentes
└── Protocolo_Seguridad.md        # Protocolo detallado de operaciones DML/DDL
```

---

## ⚙️ Módulos Principales del Proyecto

### 1. Modelado y Estructura Relacional
- **Esquema (`schema_tp1.sql`)**: Definición de entidades fundamentales (Clientes, Productos, Pedidos, Detalles de Pedido, etc.) con sus respectivas claves primarias, foráneas y restricciones de dominio.

### 2. Reglas de Integridad y Triggers (`reglas_integridad.sql`)
Implementación de restricciones avanzadas de negocio a nivel de base de datos:
- **Regla 1**: Validación estricta que impide registrar pedidos con productos inactivos (`producto.activo = TRUE`).
- **Regla 2**: Restricción transaccional/disparador que garantiza que todo pedido posea al menos un ítem en su detalle.

### 3. Carga Masiva y Optimización
- Población eficiente de volúmenes significativos de datos para pruebas de rendimiento.
- Consultas optimizadas (`consultas_optimizacion - Tp3.sql`) para reportes de ventas, análisis de stock y comportamiento de clientes.

### 4. Laboratorio de Concurrencia y Transacciones
- Análisis empírico de anomalías de concurrencia (lecturas no repetibles, lecturas fantasma).
- Evaluación comparativa de niveles de aislamiento en PostgreSQL (`READ COMMITTED` vs. `REPEATABLE READ`).

---

## 🗄️ Base de Datos y Seguridad

Para garantizar la integridad operativa y evitar modificaciones destructivas sobre los datos de producción o referencia original, se opera bajo estricto protocolo:

| Base de Datos | Rol / Propósito |
| :--- | :--- |
| `Food_Store` / `practica_bd2` | Base de datos original de referencia (**Sólo lectura**). |
| `Food_Store_Copia` / `practica_bd2_tp` | Entorno de trabajo aislado para pruebas, DML y DDL. |

> **⚠️ Nota de Seguridad:** Toda operación de modificación estructural (DDL) requiere la generación previa de un respaldo (`pg_dump`) ubicado en `./db/backups/`. Las operaciones DML críticas deben validarse mediante transacciones de prueba (`BEGIN ... ROLLBACK`).

---

## 📚 Documentación Complementaria

Dentro de la carpeta `docs/` se encuentran detallados los informes y especificaciones de cada trabajo práctico:
- [`spec_integridad.md`](spec_integridad.md) — Especificación de reglas de integridad.
- [`informe_concurrencia.md`](informe_concurrencia.md) — Pruebas y conclusiones de concurrencia.
- [`ejercicio_lectura_critica.md`](ejercicio_lectura_critica.md) — Lectura crítica y optimización.
- Documentos de TPs (`DUIA_TP2.md`, `DUIA_Tp3.md`, `DUIA_Tp4.md`).

---

## 🔄 Guía de Respaldo y Restauración

Para realizar un respaldo preventivo de la base de datos de trabajo mediante `pg_dump`:

```bash
pg_dump -U postgres -h localhost -p 5432 -F p -f "./db/backups/Food_Store_Copia_backup.sql" Food_Store_Copia
```
