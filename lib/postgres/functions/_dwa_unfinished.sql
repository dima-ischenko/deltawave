create or replace function _dwa_unfinished()
returns integer
language plpgsql stable
set search_path = pg_temp, :"dwa_schema", public as $$
begin
  if exists (
    select 1
    from dwa_keys_tmp
    where batch_no is not null
     and batch_done = 0
  ) then
    return 1;
  end if;
  return 0;
end;
$$;
