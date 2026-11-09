-- The relation must be visible and selectable by the caller.
create or replace function _dwa_assert_relation(p_owner text, p_table text)
returns void
language plpgsql
set search_path = pg_catalog, :"dwa_schema" as $$
declare
l_reg regclass;
begin
  l_reg := to_regclass(format('%I.%I', p_owner, p_table));
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
