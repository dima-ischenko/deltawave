-- Installed library version. Written on the dwa_initialize log line.
create or replace function dwa_version()
returns text
language sql
immutable as $$
  select '1.0.2';
$$;
