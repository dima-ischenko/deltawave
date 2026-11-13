-- Installed library version.
create or replace function dwa_version()
returns text
language sql
immutable as $$
  select '1.0.6'::text;
$$;
