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
l_owner    text;
l_target   text;
l_slice    text := _dwa_norm_slice(p_data_slice);
l_lookback numeric := coalesce(p_lookback_hours, 0);
l_by_id    text := '';
l_by_pk    text := '';
begin
  if l_lookback < 0 then
    raise exception 'DWA-20002 lookback_hours must be >= 0';
  end if;

  select q.o_owner, q.o_table
  into l_owner, l_target
  from _dwa_qualify_relation(p_owner, p_target_table, 'target_table') q;

  -- Temp tables are session-scoped; recreate each run (no IF NOT EXISTS on GP6).
  -- Greenplum: PK must include the distribution key.
  if position('greenplum' in lower(version())) > 0 then
    l_by_id := ' distributed by (id)';
    l_by_pk := ' distributed by (pk_1)';
  end if;

  drop table if exists dwa_batch_tmp;
  drop table if exists dwa_keys_tmp;
  drop table if exists dwa_session_tmp;

  execute format($sql$
    create temp table dwa_session_tmp (
      id              int primary key,
      target_owner    text,
      target_table    text,
      data_slice      text,
      lookback_hours  numeric,
      batch_no        numeric,
      batch_size      numeric,
      batches_ready   boolean,
      debug           boolean not null default false,
      log_table       boolean not null default false,
      constraint ck_dwa_session_tmp_id check (id = 1)
    ) on commit preserve rows%s
  $sql$, l_by_id);

  execute format($sql$
    create temp table dwa_keys_tmp (
      source_owner    text        not null,
      source_table    text        not null,
      pk_1            text        not null,
      pk_2            text,
      pk_3            text,
      watermark       timestamp   not null,
      batch_no        numeric,
      batch_done      smallint    not null default 0,
      constraint ck_dwa_keys_tmp_done check (batch_done in (0, 1))
    ) on commit preserve rows%s
  $sql$, l_by_pk);

  execute format($sql$
    create temp table dwa_batch_tmp (
      pk_1            text        not null,
      pk_2            text,
      pk_3            text
    ) on commit delete rows%s
  $sql$, l_by_pk);

  execute 'create index idx_dwa_keys_tmp_batch on dwa_keys_tmp (batch_no, batch_done)';

  insert into dwa_session_tmp (
    id, target_owner, target_table, data_slice, lookback_hours,
    batch_no, batch_size, batches_ready, debug, log_table
  ) values (
    1, l_owner, l_target, l_slice, l_lookback,
    null, null, false, p_debug is true, p_log_table is true
  );

  perform _dwa_acquire_run_lock(l_owner, l_target, l_slice);

  perform _dwa_write_log(
    'dwa_initialize',
    0,
    format(
      'version=%s target=%s.%s slice=%s lookback_hours=%s',
      dwa_version(), l_owner, l_target, l_slice, l_lookback
    )
  );
end;
$$;
