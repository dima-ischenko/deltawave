-- Remove dwa from the current schema. Safe when objects are absent.

whenever sqlerror exit sql.sqlcode

@lib/oracle/rollback_code.sql
@lib/oracle/rollback_structure.sql
