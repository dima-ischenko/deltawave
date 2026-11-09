-- Starts a run. Exclusive lock on (owner, target, slice) until dwa_finalize.
create or replace function dwa_initialize(
    p_target_table    text,
    p_owner           text default null,
    p_data_slice      text default 'all',
    p_lookback_hours  numeric default 0,
    p_debug           boolean default false,
    p_log_table       boolean default false
)
returns void
language plpgsql
set search_path = pg_temp, :"dwa_schema", public as $$
declare
l_owner   text;
l_target  text;
l_slice   text := _dwa_norm_slice(p_data_slice);
l_lookback    numeric := coalesce(p_lookback_hours, 0);
l_rows    bigint;
begin
  if l_lookback < 0 then
    raise exception 'DWA-20002 lookback_hours must be >= 0';
  end if;

  select q.o_owner, q.o_table
  into l_owner, l_target
  from _dwa_qualify_relation(p_owner, p_target_table, 'target_table') q;

  perform _dwa_ensure_temp();

  insert into dwa_session_tmp (
    id, target_owner, target_table, data_slice, lookback_hours,
    batch_no, batch_size, batches_ready, debug, log_table
  ) values (
    1, l_owner, l_target, l_slice, l_lookback,
    null, null, false, p_debug is true, p_log_table is true
  )
  on conflict (id) do update set
    target_owner = excluded.target_owner,
    target_table = excluded.target_table,
    data_slice = excluded.data_slice,
    lookback_hours = excluded.lookback_hours,
    batch_no = null,
    batch_size = null,
    batches_ready = false,
    debug = excluded.debug,
    log_table = excluded.log_table;

  perform _dwa_acquire_run_lock(l_owner, l_target, l_slice);

  delete from dwa_keys_tmp;
  get diagnostics l_rows = row_count;

  delete from dwa_batch_tmp;

  perform _dwa_write_log(
    'dwa_initialize',
    l_rows,
    format(
      'version=%s target=%s.%s slice=%s lookback_hours=%s',
      dwa_version(), l_owner, l_target, l_slice, l_lookback
    )
  );
end;
$$;
