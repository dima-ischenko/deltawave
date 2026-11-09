-- Remove this install from the selected schema. Safe when objects are absent.
--   psql -v ON_ERROR_STOP=1 -v dwa_schema=analytics -f lib/postgres/rollback.sql
\i lib/postgres/_install_schema.sql
\i lib/postgres/rollback_code.sql
\i lib/postgres/rollback_structure.sql
