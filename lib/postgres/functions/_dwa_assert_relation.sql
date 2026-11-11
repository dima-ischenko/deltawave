-- The relation must be visible and selectable by the caller.
create or replace function _dwa_assert_relation(p_owner text, p_table text)
returns void
language plpgsql
set search_path = pg_catalog, :"dwa_schema" as $$
declare
l_reg regclass;
begin
  -- to_regclass(text) is PG 9.5+; GP6 / PG 9.4 only has to_regclass(cstring).
  select c.oid
  into l_reg
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = p_owner
    and c.relname = p_table
    and c.relkind in ('r', 'p', 'v', 'm', 'f');

  if l_reg is null then
    raise exception
      'DWA-20022 table %.% does not exist or is not available',
      p_owner, p_table;
  end if;
  if not has_table_privilege(l_reg, 'SELECT') then
    raise exception
      'DWA-20022 table %.% does not exist or is not available',
      p_owner, p_table;
  end if;
end;
$$;
