-- Unqualified identifier.
create or replace function _dwa_norm_ident(p_name text, p_label text)
returns text
language plpgsql
set search_path = pg_catalog, :"dwa_schema" as $$
declare
l_name text;
begin
  if p_name is null then
    raise exception 'DWA-20006 % is required', p_label;
  end if;

  l_name := lower(trim(p_name));
  if l_name is null or length(l_name) = 0 then
    raise exception 'DWA-20006 % is required', p_label;
  end if;
  if position('.' in l_name) > 0 then
    raise exception 'DWA-20006 % must be unqualified; pass p_owner for the schema', p_label;
  end if;
  if l_name !~ '^[a-z][a-z0-9_#$]*$' then
    raise exception 'DWA-20022 invalid % %', p_label, p_name;
  end if;

  return l_name;
end;
$$;
