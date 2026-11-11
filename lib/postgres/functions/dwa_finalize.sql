-- Writes watermarks, releases the lock. Does not commit.
create or replace function dwa_finalize()
returns void
language plpgsql
set search_path = pg_temp, :"dwa_schema", public as $$
declare
l_owner      text;
l_target     text;
l_slice      text;
l_ready      boolean;
l_left       integer := 0;
l_unassigned integer := 0;
l_moved      integer := 0;
l_inserted   integer := 0;
l_all_pk     integer := 0;
l_now        timestamp;
begin
  if to_regclass('dwa_session_tmp') is null then
    raise exception 'DWA-20001 Call dwa_initialize first';
  end if;

  select target_owner, target_table, data_slice, batches_ready
  into l_owner, l_target, l_slice, l_ready
  from dwa_session_tmp
  where id = 1;

  if l_target is null then
    raise exception 'DWA-20001 Call dwa_initialize first';
  end if;

  if l_ready then
    l_left := _dwa_unfinished();
    l_unassigned := _dwa_unassigned();
  end if;

  if l_left > 0
   or l_unassigned > 0 then
    raise exception
      'DWA-20005 unfinished batches for %.% (% left). Watermark was not moved. Finish the remaining batches before calling dwa_finalize.',
      l_owner, l_target, l_left;
  end if;

  -- GP6 / PG 9.4: no INSERT ... ON CONFLICT. Same rule: watermark never moves back.
  l_now := clock_timestamp()::timestamp;

  update dwa_watermark w
  set watermark = s.watermark,
    updated_at = l_now
  from (
    select source_owner, source_table, max(watermark) as watermark
    from dwa_keys_tmp
    group by source_owner, source_table
  ) s
  where w.target_owner = l_owner
   and w.target_table = l_target
   and w.data_slice = l_slice
   and w.source_owner = s.source_owner
   and w.source_table = s.source_table
   and w.watermark < s.watermark;

  get diagnostics l_moved = row_count;

  insert into dwa_watermark (
    target_owner, target_table, data_slice,
    source_owner, source_table, watermark, updated_at
  )
  select l_owner,
     l_target,
     l_slice,
     s.source_owner,
     s.source_table,
     s.watermark,
     l_now
  from (
    select source_owner, source_table, max(watermark) as watermark
    from dwa_keys_tmp
    group by source_owner, source_table
  ) s
  where not exists (
    select 1
    from dwa_watermark w
    where w.target_owner = l_owner
     and w.target_table = l_target
     and w.data_slice = l_slice
     and w.source_owner = s.source_owner
     and w.source_table = s.source_table
  );

  get diagnostics l_inserted = row_count;
  l_moved := l_moved + l_inserted;

  if _dwa_debug() then
    select count(*)::integer
    into l_all_pk
    from (
      select distinct pk_1, pk_2, pk_3
      from dwa_keys_tmp
    ) k;
    perform _dwa_write_log(
      'dwa_finalize',
      l_moved,
      format('moved=%s distinct_pk=%s', l_moved, l_all_pk)
    );
  else
    perform _dwa_write_log('dwa_finalize', l_moved, format('moved=%s', l_moved));
  end if;

  delete from dwa_batch_tmp;
  perform _dwa_release_run_lock(l_owner, l_target, l_slice);

  update dwa_session_tmp
  set target_owner = null,
    target_table = null,
    data_slice = null,
    lookback_hours = 0,
    batch_no = null,
    batch_size = null,
    batches_ready = false
  where id = 1;
end;
$$;
