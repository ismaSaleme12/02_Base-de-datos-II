# Repository Instructions & Database Safety Protocol

## Database Mandates
- **Target DB:** Execute all queries and scripts against `practica_bd2_tp`. Never modify the original `practica_bd2` database.

## Safety Workflow
- **DML Verification (Insert / Update / Delete):**
  - First run in a non-committing transaction to verify affected rows:
    ```sql
    BEGIN;
    -- operation
    ROLLBACK;
    ```
  - Only execute with `COMMIT` after manual or automated verification of results.
- **DDL / Structural Changes (Alter / Drop / Migrations):**
  - Run `pg_dump` to create a backup in `./backups/` prior to any structural modifications:
    ```bash
    pg_dump -U postgres -h localhost -p 5432 -F p -f ".\backups\practica_bd2_tp_backup.sql" practica_bd2_tp
    ```
- **Script Inspection:**
  - Inspect all AI-generated or external SQL scripts before execution.
