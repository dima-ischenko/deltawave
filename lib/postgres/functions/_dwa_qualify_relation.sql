-- Resolve owner and table. Omitted p_owner uses the install schema / public.
create or replace function _dwa_qualify_relation(
    p_owner text,
    p_table text,
    p_label text,
    out o_owner text,
    out o_table text
)
language plpgsql
set search_path = :"dwa_schema", public as $$
declare
l_reg     regclass;
l_trim    text := lower(trim(p_owner));
l_schemas text[];
l_schema  text;
l_i       integer;
l_n       integer;
begin
  o_table := _dwa_norm_ident(p_table, p_label);

  if l_trim is not null and length(l_trim) > 0 then
    o_owner := _dwa_norm_ident(l_trim, 'owner');
    perform _dwa_assert_relation(o_owner, o_table);
    return;
  end if;

  -- GP6 SQL parser rejects func()[i]; walk search_path in plpgsql instead.
  l_schemas := current_schemas(false);
  l_n := coalesce(array_upper(l_schemas, 1), 0);
  l_i := 1;
  while l_i <= l_n loop
    l_schema := l_schemas[l_i];
    select lower(n.nspname), c.oid
    into o_owner, l_reg
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where c.relname = o_table
      and c.relkind in ('r', 'p', 'v', 'm', 'f')
      and n.nspname = l_schema;
    if l_reg is not null then
      exit;
    end if;
    l_i := l_i + 1;
  end loop;

  if l_reg is null then
    raise exception
      'DWA-20022 table % does not exist or is not available',
      o_table;
  end if;

  if not has_table_privilege(l_reg, 'SELECT') then
    raise exception
      'DWA-20022 table %.% does not exist or is not available',
      o_owner, o_table;
  end if;
end;
$$;
