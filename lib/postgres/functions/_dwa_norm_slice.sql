-- Slice is a watermark key, not a relation name. Digits are allowed ('1', '101').
create or replace function _dwa_norm_slice(p_name text)
returns text
language plpgsql
set search_path = pg_catalog, :"dwa_schema" as $$
declare
l_name text;
begin
  if p_name is null then
    raise exception 'DWA-20006 data_slice is required';
  end if;

  l_name := lower(trim(p_name));
  if l_name is null or length(l_name) = 0 then
    raise exception 'DWA-20006 data_slice is required';
  end if;
  if position('.' in l_name) > 0
     or l_name !~ '^[a-z0-9_#$]+$' then
    raise exception 'DWA-20022 invalid data_slice %', p_name;
  end if;

  return l_name;
end;
$$;
