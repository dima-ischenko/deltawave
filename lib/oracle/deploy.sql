-- Deploy dwa into the current schema. Start from the repository root.

whenever sqlerror exit sql.sqlcode

@lib/oracle/deploy_structure.sql
@lib/oracle/deploy_code.sql
