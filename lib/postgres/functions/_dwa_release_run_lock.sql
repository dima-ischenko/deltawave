create or replace function _dwa_release_run_lock(p_owner text, p_target text, p_slice text)
returns void
language plpgsql
set search_path = pg_catalog, :"dwa_schema" as $$
declare
c_ns   constant integer := 4478785;
l_name text := 'DWA|' || p_owner || '.' || p_target || '|' || p_slice;
begin
  if pg_advisory_unlock(c_ns, hashtext(l_name)) then
    perform _dwa_write_log('dwa_finalize', 0, 'lock released name=' || l_name);
  end if;
end;
$$;
